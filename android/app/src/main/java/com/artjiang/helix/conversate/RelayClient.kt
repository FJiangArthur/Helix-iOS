// HTTP client for helix-relay (contract 0.3 §7). The relay owns every
// upstream secret; the app holds only its URL and one bearer key, both kept
// in the encrypted key store (never in HelixSettings JSON).
package com.artjiang.helix.conversate

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.Job
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.Call
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit

data class RelayConfig(val baseUrl: String, val key: String)

class RelayException(val kind: Kind, message: String, cause: Throwable? = null) : Exception(message, cause) {
    enum class Kind { NOT_CONFIGURED, UNREACHABLE, UNAUTHORIZED, FAILED }
}

@Serializable
data class RelayItem(val id: String, val title: String, val detail: String = "")

@Serializable
data class RelayTodo(
    val id: String,
    val title: String,
    val detail: String = "",
    val completed: Boolean = false,
    val dueAt: String? = null,
)

@Serializable
data class RelayDashboard(
    val generatedAt: String = "",
    val briefing: List<String> = emptyList(),
    val news: List<RelayItem> = emptyList(),
    val x: List<RelayItem> = emptyList(),
    val todos: List<RelayTodo> = emptyList(),
    val omi: List<RelayItem> = emptyList(),
) {
    /** Panel rows for a contract 0.3 §5 panel kind; unknown kinds are empty. */
    fun rows(kind: String): List<PanelRow> = when (kind) {
        "todos" -> todos.map { PanelRow(it.id, it.title, it.detail, it.completed) }
        "news" -> news.map { PanelRow(it.id, it.title, it.detail) }
        "x" -> x.map { PanelRow(it.id, it.title, it.detail) }
        "omi" -> omi.map { PanelRow(it.id, it.title, it.detail) }
        else -> emptyList()
    }
}

@Serializable
data class RelayReminder(val id: String, val kind: String = "", val text: String, val dueAt: String? = null)

@Serializable
private data class RemindersBody(val reminders: List<RelayReminder> = emptyList())

@Serializable
private data class HealthBody(val ok: Boolean = false, val version: String = "")

class RelayClient(
    private val config: () -> RelayConfig?,
    private val http: OkHttpClient = defaultHttp,
) {
    companion object {
        /** Key-store kinds (SettingsRepository.setKey); both live only in encrypted prefs. */
        const val URL_KEY_KIND = "HELIX_RELAY_URL"
        const val BEARER_KEY_KIND = "HELIX_RELAY_KEY"

        private val JSON = "application/json".toMediaType()
        private val defaultHttp: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .build()
        }
    }

    suspend fun health(): String {
        val body = execute(request("health", auth = false).get().build())
        return conversateJson.decodeFromString(HealthBody.serializer(), body).version
    }

    suspend fun getDashboard(): RelayDashboard =
        conversateJson.decodeFromString(RelayDashboard.serializer(), execute(request("dashboard").get().build()))

    suspend fun patchTodo(id: String, completed: Boolean) {
        val body = buildJsonObject { put("completed", completed) }.toString().toRequestBody(JSON)
        execute(request("todos", id).patch(body).build())
    }

    suspend fun getReminders(sinceMillis: Long): List<RelayReminder> {
        val req = request("reminders") { addQueryParameter("since", sinceMillis.toString()) }.get().build()
        return conversateJson.decodeFromString(RemindersBody.serializer(), execute(req)).reminders
    }

    /**
     * POST /ask and read the SSE stream (`data: {"delta"}` ... `{"done":true}`).
     * [onDelta] runs on the IO thread for each chunk; returns the whole answer.
     * Cancelling the caller cancels the HTTP call.
     */
    suspend fun ask(question: String, context: String?, deep: Boolean, onDelta: (String) -> Unit): String {
        val payload = buildJsonObject {
            put("question", question)
            if (!context.isNullOrBlank()) put("context", context)
            put("deep", deep)
        }.toString().toRequestBody(JSON)
        val req = request("ask").post(payload).header("Accept", "text/event-stream").build()
        return withCall(req) { response ->
            val source = response.body?.source() ?: throw RelayException(RelayException.Kind.FAILED, "Empty response")
            val answer = StringBuilder()
            while (true) {
                val line = source.readUtf8Line() ?: break
                if (!line.startsWith("data:")) continue
                val data = line.removePrefix("data:").trim()
                if (data.isEmpty()) continue
                val event = runCatching { conversateJson.parseToJsonElement(data).jsonObject }.getOrNull() ?: continue
                event.string("error")?.let { throw RelayException(RelayException.Kind.FAILED, it) }
                event.string("delta")?.let { answer.append(it); onDelta(it) }
                if (event["done"]?.jsonPrimitive?.booleanOrNull == true) break
            }
            answer.toString()
        }
    }

    private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull

    private fun request(
        vararg segments: String,
        auth: Boolean = true,
        query: HttpUrl.Builder.() -> Unit = {},
    ): Request.Builder {
        val cfg = config()?.takeIf { it.baseUrl.isNotBlank() && (!auth || it.key.isNotBlank()) }
            ?: throw RelayException(RelayException.Kind.NOT_CONFIGURED, "Helix relay is not set up")
        val base = cfg.baseUrl.trim().toHttpUrlOrNull()
            ?: throw RelayException(RelayException.Kind.NOT_CONFIGURED, "Helix relay URL is invalid")
        val url = base.newBuilder().apply {
            segments.forEach { addPathSegment(it) }
            query()
        }.build()
        val builder = Request.Builder().url(url)
        if (auth) builder.header("Authorization", "Bearer ${cfg.key.trim()}")
        return builder
    }

    private suspend fun execute(req: Request): String = withCall(req) { it.body?.string().orEmpty() }

    private suspend fun <T> withCall(req: Request, read: (Response) -> T): T {
        val call: Call = http.newCall(req)
        val job = currentCoroutineContext()[Job]
        val handle = job?.invokeOnCompletion { call.cancel() }
        try {
            return withContext(Dispatchers.IO) {
                val response = try {
                    call.execute()
                } catch (e: IOException) {
                    currentCoroutineContext().ensureActive()
                    throw RelayException(RelayException.Kind.UNREACHABLE, "Relay unreachable", e)
                }
                response.use {
                    when {
                        it.code == 401 -> throw RelayException(RelayException.Kind.UNAUTHORIZED, "Relay key rejected")
                        !it.isSuccessful -> throw RelayException(RelayException.Kind.FAILED, "Relay error ${it.code}")
                    }
                    try {
                        read(it)
                    } catch (e: IOException) {
                        currentCoroutineContext().ensureActive()
                        throw RelayException(RelayException.Kind.UNREACHABLE, "Relay connection dropped", e)
                    }
                }
            }
        } finally {
            handle?.dispose()
        }
    }
}
