// Manual import from Omi (app.omi.me) — fetches the user's conversations and
// memories over the Omi developer REST API and hands them to the local stores.
// Import is idempotent: every record carries a stable "omi:<remoteId>" id, so
// re-running the import skips anything already stored.
package com.artjiang.helix.data

import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import com.artjiang.helix.core.SessionSummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.time.Instant
import java.time.OffsetDateTime

/** HTTP failure from the Omi API, carrying the status and a body snippet. */
class OmiHttpException(val statusCode: Int, bodySnippet: String) :
    IOException("Omi request failed with HTTP $statusCode: $bodySnippet")

/** 200 OK, but the payload matched none of the known response envelopes. */
class OmiUnexpectedResponseException(bodySnippet: String) :
    IOException("Omi returned an unrecognized response shape: $bodySnippet")

/** No Omi developer key is stored — the import cannot authenticate. */
class OmiMissingKeyException :
    IOException("No Omi API key stored. Add your omi_dev_… key in Settings first.")

data class OmiImportResult(
    val conversationsImported: Int,
    val memoriesImported: Int,
    val duplicatesSkipped: Int,
)

/**
 * Fetch + map + hand off. The sinks are injected as functions (rather than the
 * repositories themselves, which need an Android Context) so the service is
 * plain-JVM testable against MockWebServer.
 */
class OmiImportService(
    private val keyStore: KeyStore,
    private val upsertSessions: suspend (List<SessionSummary>) -> Int,
    private val upsertKnowledge: suspend (List<KnowledgeItem>) -> Int,
    private val client: OkHttpClient = OkHttpClient(),
    private val baseUrl: String = DEFAULT_BASE_URL,
) {

    suspend fun importAll(): OmiImportResult = withContext(Dispatchers.IO) {
        val key = keyStore.keyFor(KEY_KIND) ?: throw OmiMissingKeyException()
        val conversations = fetchAll("$baseUrl/v1/dev/user/conversations", key, "conversations")
        val memories = fetchAll("$baseUrl/v1/dev/user/memories", key, "memories")

        val sessions = conversations.mapNotNull(::sessionFrom)
        val items = memories.mapNotNull(::knowledgeFrom)
        val sessionsAdded = upsertSessions(sessions)
        val itemsAdded = upsertKnowledge(items)
        OmiImportResult(
            conversationsImported = sessionsAdded,
            memoriesImported = itemsAdded,
            duplicatesSkipped = (sessions.size - sessionsAdded) + (items.size - itemsAdded),
        )
    }

    /** Pages with limit/offset until a short page; bounded by [MAX_PAGES]. */
    private fun fetchAll(url: String, key: String, collectionKey: String): List<JsonObject> {
        val results = mutableListOf<JsonObject>()
        var offset = 0
        repeat(MAX_PAGES) {
            val page = fetchPage("$url?limit=$PAGE_SIZE&offset=$offset", key, collectionKey)
            results += page
            if (page.size < PAGE_SIZE) return results
            offset += PAGE_SIZE
        }
        return results
    }

    private fun fetchPage(url: String, key: String, collectionKey: String): List<JsonObject> {
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $key")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw OmiHttpException(response.code, body.take(BODY_SNIPPET_LIMIT))
            }
            val root = runCatching { json.parseToJsonElement(body) }.getOrNull()
                ?: throw OmiHttpException(response.code, "unparseable body")
            // The API returns either a bare array or {"<collection>": [...]}.
            val array: JsonArray = when {
                root is JsonArray -> root
                root is JsonObject && root[collectionKey] is JsonArray -> root[collectionKey]!!.jsonArray
                root is JsonObject && root["items"] is JsonArray -> root["items"]!!.jsonArray
                // Fail loudly: silently treating an unknown envelope as "no
                // items" would record a successful import that synced nothing.
                else -> throw OmiUnexpectedResponseException(body.take(BODY_SNIPPET_LIMIT))
            }
            return array.mapNotNull { it as? JsonObject }
        }
    }

    // MARK: - Mapping

    internal fun sessionFrom(obj: JsonObject): SessionSummary? {
        val remoteId = remoteId(obj) ?: return null
        val structured = obj["structured"] as? JsonObject
        val title = structured?.string("title")?.takeIf { it.isNotBlank() } ?: "Omi conversation"
        return SessionSummary(
            id = "$ID_PREFIX$remoteId",
            title = title,
            answerPreview = structured?.string("overview").orEmpty(),
            transcriptTurns = transcriptTurns(obj),
            answerCount = 0,
            createdAtMillis = timestampMillis(obj.string("started_at") ?: obj.string("created_at")),
        )
    }

    internal fun knowledgeFrom(obj: JsonObject): KnowledgeItem? {
        val remoteId = remoteId(obj) ?: return null
        val text = (obj.string("content") ?: obj.string("text") ?: obj.string("memory"))
            ?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return KnowledgeItem(
            id = "$ID_PREFIX$remoteId",
            bucket = KnowledgeBucket.MEMORIES,
            text = text,
            source = SOURCE_NAME,
            createdAtMillis = timestampMillis(obj.string("created_at")),
        )
    }

    private fun transcriptTurns(obj: JsonObject): List<String> =
        ((obj["transcript_segments"] as? JsonArray) ?: JsonArray(emptyList()))
            .mapNotNull { seg ->
                val segObj = seg as? JsonObject ?: return@mapNotNull null
                val text = segObj.string("text")?.trim()?.takeIf { it.isNotEmpty() }
                    ?: return@mapNotNull null
                val speaker = segObj.string("speaker")?.takeIf { it.isNotBlank() }
                if (speaker != null) "$speaker: $text" else text
            }
            .take(MAX_TRANSCRIPT_TURNS)

    /** A blank id would collapse every such record onto the "omi:" key. */
    private fun remoteId(obj: JsonObject): String? =
        obj.string("id")?.trim()?.takeIf { it.isNotEmpty() }

    private fun JsonObject.string(key: String): String? =
        (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.content

    /** Omi timestamps arrive as ISO-8601 (sometimes space-separated). */
    internal fun timestampMillis(raw: String?): Long {
        if (raw.isNullOrBlank()) return System.currentTimeMillis()
        val normalized = raw.trim().replaceFirst(' ', 'T')
        return runCatching { Instant.parse(normalized).toEpochMilli() }
            .recoverCatching { OffsetDateTime.parse(normalized).toInstant().toEpochMilli() }
            .getOrElse { System.currentTimeMillis() }
    }

    companion object {
        const val KEY_KIND = "OMI"
        const val SOURCE_NAME = "Omi"
        const val ID_PREFIX = "omi:"
        const val DEFAULT_BASE_URL = "https://api.omi.me"
        const val PAGE_SIZE = 100
        const val MAX_PAGES = 20
        const val MAX_TRANSCRIPT_TURNS = 200
        const val BODY_SNIPPET_LIMIT = 512
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    }
}
