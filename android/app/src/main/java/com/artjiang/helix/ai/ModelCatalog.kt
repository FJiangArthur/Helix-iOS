// Model discovery and API-key validation. Mirrors
// NativeHelix/Sources/HelixAI/ModelCatalog.swift (roles, prefix rules,
// curated fallbacks) so both apps agree on what "chat-capable" means.
package com.artjiang.helix.ai

import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull
import java.io.IOException
import java.time.OffsetDateTime
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient

/**
 * The role a model plays. Chat models power answers; realtime and
 * transcription models must never reach the chat picker because
 * `/chat/completions` rejects them.
 */
enum class ModelRole { CHAT, REALTIME, TRANSCRIPTION }

/** One entry of a provider's `GET /models` reply. */
data class DiscoveredModel(
    val id: String,
    /** `created` (OpenAI family, epoch seconds) or `created_at` (Anthropic, ISO-8601). */
    val createdEpochSeconds: Long? = null,
)

/** Verdict of [ModelCatalog.checkKey]; never an exception. */
sealed class KeyCheckResult {
    /** The key authenticated; [models] is the raw list the endpoint returned. */
    data class Ok(val models: List<DiscoveredModel>) : KeyCheckResult()

    /** 401/403 — the key itself was rejected. */
    data class Invalid(val message: String) : KeyCheckResult()

    /** 404/405 — the key may be fine but the provider has no `/models`. */
    data class Unsupported(val message: String) : KeyCheckResult()

    /** Network, rate limit, server error, or an unparseable body. */
    data class Failed(val message: String) : KeyCheckResult()
}

/**
 * Fetches and caches the model IDs a provider offers so Settings can present
 * a live, editable list instead of a hard-coded value. Every supported
 * provider exposes an OpenAI-style `GET /models` (Anthropic with a different
 * auth header); without a key, or when the endpoint fails, the curated
 * fallback keeps the picker populated.
 */
class ModelCatalog(
    private val client: OkHttpClient = OpenAiCompatibleProvider.defaultClient,
    private val baseUrlFor: (ProviderKind) -> String = ProviderEndpoints::forKind,
    private val clock: () -> Long = System::currentTimeMillis,
    private val ttlMillis: Long = DEFAULT_TTL_MILLIS,
) {
    data class CacheEntry(val models: List<DiscoveredModel>, val fetchedAtMillis: Long)

    private val cache = ConcurrentHashMap<ProviderKind, CacheEntry>()

    /**
     * Live `GET /models`. Throws [ProviderHttpException] on non-2xx,
     * [ProviderEmptyResponseException] on an unparseable body, and plain
     * [IOException] on transport failure. A successful fetch refreshes the cache.
     */
    suspend fun fetchModels(kind: ProviderKind, apiKey: String): List<DiscoveredModel> {
        val key = apiKey.trim()
        if (key.isEmpty()) throw MissingApiKeyException(kind)
        val models = withContext(Dispatchers.IO) {
            val root = getJsonForObject(
                client = client,
                url = modelsUrl(kind, baseUrlFor(kind)),
                headers = authHeadersFor(kind, key),
                kind = kind,
            )
            parseModels(root, kind)
        }
        cache[kind] = CacheEntry(models, clock())
        return models
    }

    /** Validates [apiKey] against the provider; maps every failure to a verdict. */
    suspend fun checkKey(kind: ProviderKind, apiKey: String): KeyCheckResult {
        if (apiKey.isBlank()) return KeyCheckResult.Invalid(INVALID_KEY_MESSAGE)
        return try {
            KeyCheckResult.Ok(fetchModels(kind, apiKey))
        } catch (error: ProviderHttpException) {
            val message = describe(error, kind)
            when (error.statusCode) {
                401, 403 -> KeyCheckResult.Invalid(message)
                404, 405 -> KeyCheckResult.Unsupported(message)
                else -> KeyCheckResult.Failed(message)
            }
        } catch (error: Exception) {
            KeyCheckResult.Failed(describe(error, kind))
        }
    }

    /**
     * Selectable IDs for [role]: cache while fresh, otherwise live, otherwise
     * the curated fallback (stale cache preferred over nothing). No key means
     * no request at all.
     */
    suspend fun listModels(
        kind: ProviderKind,
        apiKey: String?,
        role: ModelRole = ModelRole.CHAT,
        forceRefresh: Boolean = false,
    ): List<String> {
        val key = apiKey?.trim().orEmpty()
        if (key.isEmpty()) return options(null, kind, role)

        val existing = cached(kind)
        if (!forceRefresh && existing != null && isFresh(existing)) {
            return options(existing.models, kind, role)
        }
        val live = runCatching { fetchModels(kind, key) }.getOrNull() ?: existing?.models
        return options(live, kind, role)
    }

    /** Last fetched list for [kind], fresh or stale. */
    fun cached(kind: ProviderKind): CacheEntry? = cache[kind]

    fun invalidate(kind: ProviderKind) {
        cache.remove(kind)
    }

    private fun isFresh(entry: CacheEntry): Boolean = clock() - entry.fetchedAtMillis < ttlMillis

    companion object {
        val DEFAULT_TTL_MILLIS: Long = TimeUnit.MINUTES.toMillis(60)
        const val INVALID_KEY_MESSAGE = "Invalid API key"

        /**
         * IDs carrying any of these tokens are never chat models, whatever the
         * prefix says (OpenAI lists `gpt-4o-mini-tts`, `gpt-image-1`, …).
         */
        private val NON_CHAT_TOKENS = listOf(
            "embedding", "tts", "whisper", "dall-e", "image", "moderation", "audio",
            "realtime", "transcribe", "instruct", "codex", "computer-use", "search-preview",
        )

        /** `gpt-4.1-2025-04-14` → alias `gpt-4.1`. */
        private val DATED_SNAPSHOT = Regex("^(.+)-\\d{4}-\\d{2}-\\d{2}$")

        /** Extra curated IDs appended after the Domain defaults, per provider. */
        private val CHAT_EXTRAS = mapOf(
            ProviderKind.OPENAI to listOf("gpt-4.1-nano"),
            ProviderKind.DEEPSEEK to listOf("deepseek-v4-pro"),
            ProviderKind.QWEN to listOf("qwen-plus"),
        )

        private val OPENAI_REALTIME_FALLBACKS = listOf("gpt-realtime", "gpt-4o-mini-realtime")

        /**
         * The transcription models the realtime websocket
         * (`?intent=transcription`) actually accepts.
         *
         * This is the WHOLE allow-list, not a "curated subset" — OpenAI also
         * ships batch-only `/v1/audio/transcriptions` models whose ids contain
         * "transcribe" (`gpt-transcribe`, shipped July 2026). Those stream
         * nothing over the realtime socket: the session opens, no delta ever
         * arrives, and the first-delta watchdog fires. Offering one in the
         * realtime picker is therefore offering a guaranteed failure, so the
         * picker is restricted to exactly these ids rather than to everything
         * matching "transcribe".
         */
        val OPENAI_TRANSCRIPTION_FALLBACKS = listOf(
            "gpt-live-transcribe", "gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1",
        )

        /**
         * True when [id] is a transcription model the realtime endpoint can
         * stream. Dated snapshots of an allowed alias count
         * (`gpt-4o-transcribe-2025-03-20`), because the API accepts them.
         */
        fun isRealtimeTranscriptionModel(id: String): Boolean {
            val lowered = id.trim().lowercase()
            if (lowered.isEmpty()) return false
            return OPENAI_TRANSCRIPTION_FALLBACKS.any { allowed ->
                lowered == allowed || DATED_SNAPSHOT.matchEntire(lowered)?.groupValues?.get(1) == allowed
            }
        }

        /**
         * Coerces a persisted transcription model to one the realtime endpoint
         * can use. Users who selected `gpt-transcribe` before it was filtered
         * out are otherwise stuck in a permanently failing state after
         * updating, with no in-app way to tell which ids are valid.
         */
        fun sanitizeRealtimeTranscriptionModel(id: String?, default: String): String {
            val trimmed = id?.trim().orEmpty()
            return if (isRealtimeTranscriptionModel(trimmed)) trimmed else default
        }

        /** `DETERMINISTIC` has no endpoint or table row; it borrows OpenAI's. */
        private fun tableKind(kind: ProviderKind): ProviderKind =
            if (kind == ProviderKind.DETERMINISTIC) ProviderKind.OPENAI else kind

        /**
         * Classifies a model ID, or null when it is not usable by Helix for
         * this provider (embeddings, images, moderation, foreign ids, …).
         */
        fun roleOf(id: String, kind: ProviderKind): ModelRole? {
            val lowered = id.trim().lowercase()
            if (lowered.isEmpty()) return null
            // Role suffixes are provider-independent in the OpenAI dialect.
            if (lowered.contains("transcribe") || lowered == "whisper-1") return ModelRole.TRANSCRIPTION
            if (lowered.contains("realtime")) return ModelRole.REALTIME
            if (NON_CHAT_TOKENS.any { lowered.contains(it) }) return null

            val isChat = when (tableKind(kind)) {
                ProviderKind.OPENAI ->
                    lowered.startsWith("gpt-") || lowered.startsWith("chatgpt-") ||
                        Regex("^o\\d").containsMatchIn(lowered)

                ProviderKind.ANTHROPIC -> lowered.startsWith("claude")
                ProviderKind.DEEPSEEK -> lowered.startsWith("deepseek")
                ProviderKind.QWEN -> lowered.startsWith("qwen")
                ProviderKind.ZHIPU -> lowered.startsWith("glm")
                ProviderKind.DETERMINISTIC -> false
            }
            return if (isChat) ModelRole.CHAT else null
        }

        /**
         * Curated list shown without a key or when discovery fails. Chat
         * fallbacks start with the Domain default table (smart, then light)
         * so the first entry is always the configured default.
         */
        fun fallbackModels(kind: ProviderKind, role: ModelRole = ModelRole.CHAT): List<String> {
            val table = tableKind(kind)
            return when (role) {
                ModelRole.CHAT -> {
                    val row = HelixSettings.defaultProviders()[table.name]
                    (listOfNotNull(row?.smartModel, row?.lightModel) + CHAT_EXTRAS[table].orEmpty())
                        .distinct()
                }

                ModelRole.REALTIME ->
                    if (table == ProviderKind.OPENAI) OPENAI_REALTIME_FALLBACKS else emptyList()

                ModelRole.TRANSCRIPTION ->
                    if (table == ProviderKind.OPENAI) OPENAI_TRANSCRIPTION_FALLBACKS else emptyList()
            }
        }

        /**
         * Picker options in display order: the pinned (currently configured)
         * id, the curated fallbacks, then live ids of [role] newest first.
         * OpenAI dated snapshots collapse into their alias when it is listed.
         */
        fun options(
            live: List<DiscoveredModel>?,
            kind: ProviderKind,
            role: ModelRole = ModelRole.CHAT,
            pinned: String? = null,
        ): List<String> {
            val ordered = LinkedHashSet<String>()
            // The pinned (currently configured) id is normally shown even when
            // discovery did not list it — except for realtime transcription,
            // where a pinned batch-only id is exactly the broken state we are
            // trying to get the user out of. Pinning it back would leave it
            // selected and selectable forever.
            pinned?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.takeIf { role != ModelRole.TRANSCRIPTION || isRealtimeTranscriptionModel(it) }
                ?.let { ordered.add(it) }

            val candidates = live.orEmpty()
                .filter { roleOf(it.id, kind) == role }
                // A model id can classify as TRANSCRIPTION and still be
                // batch-only; the realtime socket would never stream it.
                .filter { role != ModelRole.TRANSCRIPTION || isRealtimeTranscriptionModel(it.id) }
            if (candidates.isEmpty()) {
                // No live list: curated fallbacks are all we have.
                ordered.addAll(fallbackModels(kind, role))
                return ordered.toList()
            }
            // Live list present: the remote catalog leads (newest first) so the
            // picker reflects what the account can actually use today; curated
            // fallbacks are appended only as a backstop for ids the API listing
            // missed (e.g. aliases not returned by /models).
            // Fallback ids stay in the collapse set so a dated snapshot still
            // folds into a curated alias (e.g. gpt-4.1-2025-04-14 -> gpt-4.1).
            val known = ordered + candidates.map { it.id } + fallbackModels(kind, role)
            candidates
                .filterNot { isCollapsedSnapshot(it.id, kind, known) }
                .sortedByDescending { it.createdEpochSeconds ?: Long.MIN_VALUE }
                .forEach { ordered.add(it.id) }
            fallbackModels(kind, role).forEach { ordered.add(it) }
            return ordered.toList()
        }

        private fun isCollapsedSnapshot(id: String, kind: ProviderKind, known: Set<String>): Boolean {
            if (tableKind(kind) != ProviderKind.OPENAI) return false
            val alias = DATED_SNAPSHOT.matchEntire(id)?.groupValues?.get(1) ?: return false
            return alias in known
        }

        /** `GET /models`; Anthropic pages at 20 by default, so ask for everything. */
        fun modelsUrl(kind: ProviderKind, base: String): String {
            val url = base.trimEnd('/') + "/models"
            return if (kind == ProviderKind.ANTHROPIC) "$url?limit=1000" else url
        }

        /** Short, user-facing text for a discovery failure. */
        fun describe(error: Throwable, kind: ProviderKind): String {
            val provider = kind.displayName
            return when (error) {
                is ProviderHttpException -> when (error.statusCode) {
                    401, 403 -> INVALID_KEY_MESSAGE
                    404, 405 -> "Key saved · model list not available for $provider"
                    429 -> "Rate limited by $provider, try again"
                    else -> "$provider error (HTTP ${error.statusCode})"
                }

                is MissingApiKeyException -> INVALID_KEY_MESSAGE
                is ProviderEmptyResponseException -> "Unexpected response from $provider"
                is IOException ->
                    "Network error: ${error.message?.takeIf { it.isNotBlank() } ?: error.javaClass.simpleName}"

                else -> "Unexpected response from $provider"
            }
        }

        /**
         * Reads `data[]` → `id` plus `created` (epoch seconds) or `created_at`
         * (ISO-8601). A body without a `data` array is treated as unparseable.
         */
        internal fun parseModels(root: JsonObject, kind: ProviderKind): List<DiscoveredModel> {
            val data = root["data"] as? JsonArray ?: throw ProviderEmptyResponseException(kind)
            val seen = LinkedHashSet<String>()
            return data.mapNotNull { element ->
                val obj = element as? JsonObject ?: return@mapNotNull null
                val id = obj["id"]?.jsonPrimitiveOrNull()?.contentOrNull()?.trim().orEmpty()
                if (id.isEmpty() || !seen.add(id)) return@mapNotNull null
                DiscoveredModel(id = id, createdEpochSeconds = createdOf(obj))
            }
        }

        private fun createdOf(obj: JsonObject): Long? {
            obj["created"]?.jsonPrimitiveOrNull()?.longOrNull?.let { return it }
            val iso = obj["created_at"]?.jsonPrimitiveOrNull()?.contentOrNull() ?: return null
            return runCatching { OffsetDateTime.parse(iso).toEpochSecond() }.getOrNull()
        }

        private fun kotlinx.serialization.json.JsonElement.jsonPrimitiveOrNull(): JsonPrimitive? =
            this as? JsonPrimitive

        private fun JsonPrimitive.contentOrNull(): String? = if (this is JsonNull) null else content
    }
}
