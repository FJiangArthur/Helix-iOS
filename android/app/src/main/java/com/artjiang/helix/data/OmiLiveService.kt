// Live transcript feed from the Omi relay (relay/omi-relay). The Omi app POSTs
// transcript segments to the relay as a conversation unfolds; this client
// long-polls the relay's /feed endpoint and surfaces each new segment.
package com.artjiang.helix.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.longOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

data class OmiLiveSegment(
    val seq: Long,
    val text: String,
    val speaker: String?,
    val isUser: Boolean,
    val sessionId: String,
)

/**
 * Long-polls `feedUrl?after=<seq>&wait=<s>`; the relay holds the request
 * until new segments arrive (or [WAIT_SECONDS] elapses), so latency is bounded
 * by Omi's own webhook cadence rather than a polling interval.
 */
class OmiLiveService(
    private val scope: CoroutineScope,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .readTimeout(WAIT_SECONDS + 15L, TimeUnit.SECONDS)
        .build(),
) {
    private val activeState = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = activeState.asStateFlow()

    private val errorState = MutableStateFlow("")
    val errorMessage: StateFlow<String> = errorState.asStateFlow()

    private val lastSegmentState = MutableStateFlow<OmiLiveSegment?>(null)
    val lastSegment: StateFlow<OmiLiveSegment?> = lastSegmentState.asStateFlow()

    /** Invoked on the service scope for every new segment, in order. */
    var onSegment: ((OmiLiveSegment) -> Unit)? = null

    private var job: Job? = null
    private var lastSeq = 0L

    /** The blocked long-poll, cancelled on [stop] so teardown is immediate. */
    @Volatile
    private var inFlight: okhttp3.Call? = null

    fun start(feedUrl: String) {
        if (activeState.value) return
        val url = feedUrl.trim().trimEnd('/')
        if (url.isEmpty()) {
            errorState.value = "No relay URL configured."
            return
        }
        errorState.value = ""
        activeState.value = true
        job = scope.launch {
            // Skip the backlog: only show what is said from now on.
            lastSeq = runCatching { withContext(Dispatchers.IO) { fetch(url, after = 0, wait = 0) } }
                .map { it.seq }
                .getOrElse { error ->
                    fail(error)
                    return@launch
                }
            var failures = 0
            while (isActive) {
                val page = runCatching { withContext(Dispatchers.IO) { fetch(url, lastSeq, WAIT_SECONDS) } }
                    .getOrElse { error ->
                        failures += 1
                        if (failures >= MAX_CONSECUTIVE_FAILURES) {
                            fail(error)
                            return@launch
                        }
                        delay(RETRY_DELAY_MILLIS * failures)
                        null
                    } ?: continue
                failures = 0
                for (segment in page.segments) {
                    if (segment.seq <= lastSeq) continue
                    lastSeq = segment.seq
                    lastSegmentState.value = segment
                    onSegment?.invoke(segment)
                }
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        inFlight?.cancel()
        activeState.value = false
    }

    fun clearError() {
        errorState.value = ""
    }

    private fun fail(error: Throwable) {
        activeState.value = false
        job = null
        errorState.value = "Omi live feed stopped: ${error.message ?: error::class.simpleName}"
    }

    internal data class FeedPage(val seq: Long, val segments: List<OmiLiveSegment>)

    internal fun fetch(url: String, after: Long, wait: Int): FeedPage {
        val request = Request.Builder().url("$url?after=$after&wait=$wait").get().build()
        val call = client.newCall(request)
        inFlight = call
        call.execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw IOException("relay HTTP ${response.code}")
            return parseFeed(body)
        }
    }

    companion object {
        const val WAIT_SECONDS = 25
        const val MAX_CONSECUTIVE_FAILURES = 5
        const val RETRY_DELAY_MILLIS = 1_000L
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        internal fun parseFeed(body: String): FeedPage {
            val root = json.parseToJsonElement(body) as? JsonObject
                ?: throw IOException("relay returned a non-object body")
            val seq = (root["seq"] as? JsonPrimitive)?.longOrNull ?: 0L
            val segments = (root["segments"] as? JsonArray).orEmpty().mapNotNull { element ->
                val obj = element as? JsonObject ?: return@mapNotNull null
                val segSeq = (obj["seq"] as? JsonPrimitive)?.longOrNull ?: return@mapNotNull null
                val text = obj.string("text")?.trim()?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                OmiLiveSegment(
                    seq = segSeq,
                    text = text,
                    speaker = obj.string("speaker"),
                    isUser = (obj["is_user"] as? JsonPrimitive)?.booleanOrNull ?: false,
                    sessionId = obj.string("session_id").orEmpty(),
                )
            }
            return FeedPage(seq, segments)
        }

        private fun JsonObject.string(key: String): String? =
            (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull && it.isString }?.content
    }
}
