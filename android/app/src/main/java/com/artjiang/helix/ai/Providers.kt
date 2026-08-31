package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/** HTTP failure from a provider endpoint, carrying the status and a body snippet. */
class ProviderHttpException(
    val providerKind: ProviderKind,
    val statusCode: Int,
    val bodySnippet: String,
) : IOException("${providerKind.displayName} request failed with HTTP $statusCode: $bodySnippet")

/** The provider returned 2xx but no usable answer text. */
class ProviderEmptyResponseException(val providerKind: ProviderKind) :
    IOException("${providerKind.displayName} returned an empty answer.")

/** No API key was configured for a provider that requires one. */
class MissingApiKeyException(val providerKind: ProviderKind) :
    IOException("${providerKind.displayName} has no API key configured.")

internal val helixJson = Json { ignoreUnknownKeys = true; isLenient = true }
internal val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
internal const val BODY_SNIPPET_LIMIT = 512

internal fun snippet(body: String): String =
    if (body.length <= BODY_SNIPPET_LIMIT) body else body.take(BODY_SNIPPET_LIMIT) + "…"

/**
 * Shared HTTP skeleton for every provider call: execute the request, map
 * non-2xx to [ProviderHttpException], parse the response as a JSON object or
 * throw [ProviderEmptyResponseException]. Transport-level fixes (timeouts,
 * retries, redaction) land here once instead of per provider or per endpoint.
 */
internal fun executeForObject(
    client: OkHttpClient,
    request: Request,
    kind: ProviderKind,
): JsonObject {
    client.newCall(request).execute().use { response ->
        val responseBody = response.body?.string().orEmpty()
        if (!response.isSuccessful) {
            throw ProviderHttpException(kind, response.code, snippet(responseBody))
        }
        return runCatching { helixJson.parseToJsonElement(responseBody).jsonObject }.getOrNull()
            ?: throw ProviderEmptyResponseException(kind)
    }
}

/**
 * One decoded event of a `text/event-stream` body: the `data:` payload with
 * its own dialect-specific meaning left to the caller.
 */
internal data class SseEvent(val data: String)

/** Sentinel that ends an OpenAI-dialect stream. */
internal const val SSE_DONE = "[DONE]"

/**
 * Pure SSE line decoder, shared by both dialects.
 *
 * SSE frames a message as one or more `field: value` lines terminated by a
 * blank line; only `data:` carries payload, and multiple `data:` lines in one
 * frame concatenate with newlines. Everything else (`event:`, `id:`, `:`
 * comments/keep-alives) is ignored here — Anthropic sends an `event:` line
 * before every frame, but the type is also present inside the JSON payload,
 * so the parser only ever needs `data:`.
 *
 * Kept separate from the HTTP call so both dialects' delta extraction is
 * testable line-by-line without a socket.
 */
internal class SseLineDecoder {
    private val pending = StringBuilder()

    /** Feeds one raw line; returns a completed event when the frame closed. */
    fun accept(line: String): SseEvent? {
        if (line.isEmpty()) {
            if (pending.isEmpty()) return null
            val data = pending.toString()
            pending.setLength(0)
            return SseEvent(data)
        }
        if (line.startsWith(":")) return null // comment / keep-alive
        val field = line.substringBefore(':')
        // "data: x" and "data:x" are both legal; exactly one leading space is stripped.
        val value = line.substringAfter(':', missingDelimiterValue = "").removePrefix(" ")
        if (field == "data") {
            if (pending.isNotEmpty()) pending.append('\n')
            pending.append(value)
        }
        return null
    }

    /** Flushes a final frame that the body ended without a blank line after. */
    fun flush(): SseEvent? = accept("")
}

/**
 * Streams a `text/event-stream` POST, handing every decoded event to
 * [onEvent]; stop by returning false from it.
 *
 * Cancellation: the enclosing coroutine's job is checked between lines and the
 * OkHttp call is cancelled on the way out, so a cancelled answer does not leave
 * a socket draining tokens in the background. Non-2xx maps to
 * [ProviderHttpException] exactly like the buffered path.
 */
internal suspend fun streamSse(
    client: OkHttpClient,
    url: String,
    headers: Map<String, String>,
    body: JsonObject,
    kind: ProviderKind,
    onEvent: (SseEvent) -> Boolean,
) {
    val httpRequest = Request.Builder()
        .url(url)
        .apply { headers.forEach { (name, value) -> addHeader(name, value) } }
        .addHeader("Content-Type", "application/json")
        .addHeader("Accept", "text/event-stream")
        .post(body.toString().toRequestBody(JSON_MEDIA_TYPE))
        .build()

    val call = client.newCall(httpRequest)
    try {
        call.execute().use { response ->
            val responseBody = response.body ?: throw ProviderEmptyResponseException(kind)
            if (!response.isSuccessful) {
                // An error body is small and NOT event-stream; read it whole so
                // the user sees the provider's actual message (401 etc.).
                throw ProviderHttpException(kind, response.code, snippet(responseBody.string()))
            }
            val source = responseBody.source()
            val decoder = SseLineDecoder()
            while (currentCoroutineContext().isActive) {
                val line = source.readUtf8Line() ?: break
                val event = decoder.accept(line) ?: continue
                // Re-check AFTER the blocking read: cancellation almost always
                // arrives while parked in readUtf8Line, and a line that was
                // already buffered when it did must not still be dispatched —
                // otherwise a cancelled answer paints one last stale token.
                if (!currentCoroutineContext().isActive) return
                if (!onEvent(event)) return
            }
            if (currentCoroutineContext().isActive) decoder.flush()?.let { onEvent(it) }
        }
    } finally {
        // Covers both cancellation and an early `return` from onEvent: the
        // response is closed by `use`, and cancel() releases the connection
        // rather than letting OkHttp drain the remainder of the stream.
        call.cancel()
    }
}

/** POST a JSON body and parse the JSON object reply via [executeForObject]. */
internal fun postJsonForObject(
    client: OkHttpClient,
    url: String,
    headers: Map<String, String>,
    body: JsonObject,
    kind: ProviderKind,
): JsonObject {
    val httpRequest = Request.Builder()
        .url(url)
        .apply { headers.forEach { (name, value) -> addHeader(name, value) } }
        .addHeader("Content-Type", "application/json")
        .post(body.toString().toRequestBody(JSON_MEDIA_TYPE))
        .build()
    return executeForObject(client, httpRequest, kind)
}

/** GET a JSON object (used by model discovery) via [executeForObject]. */
internal fun getJsonForObject(
    client: OkHttpClient,
    url: String,
    headers: Map<String, String>,
    kind: ProviderKind,
): JsonObject {
    val httpRequest = Request.Builder()
        .url(url)
        .apply { headers.forEach { (name, value) -> addHeader(name, value) } }
        .get()
        .build()
    return executeForObject(client, httpRequest, kind)
}

/**
 * Auth headers per provider. Single source for both the answer path and
 * model discovery so the two can never disagree on how a key is presented:
 * Anthropic wants `x-api-key` + `anthropic-version`; everyone else is Bearer.
 */
internal fun authHeadersFor(kind: ProviderKind, apiKey: String): Map<String, String> {
    val key = apiKey.trim()
    return when (kind) {
        ProviderKind.ANTHROPIC -> mapOf(
            "x-api-key" to key,
            "anthropic-version" to AnthropicProvider.ANTHROPIC_VERSION,
        )

        else -> mapOf("Authorization" to "Bearer $key")
    }
}

/**
 * OpenAI reasoning models (`gpt-5*`, `o1`/`o3`/`o4`…) reject a `temperature`
 * field with HTTP 400, so the body must omit it and let the server default
 * apply. Other providers in the OpenAI dialect (DeepSeek, Qwen, Zhipu) keep
 * accepting it, including their own reasoning ids.
 *
 * Known gap, out of scope here: `o1-mini` also rejects the `system` role.
 */
internal fun omitsTemperature(kind: ProviderKind, model: String): Boolean {
    if (kind != ProviderKind.OPENAI) return false
    val lowered = model.trim().lowercase()
    return lowered.startsWith("gpt-5") || REASONING_MODEL_PREFIX.containsMatchIn(lowered)
}

private val REASONING_MODEL_PREFIX = Regex("^o\\d")

/**
 * Whether a token cap must be omitted for [model].
 *
 * Reasoning models spend tokens thinking before emitting any answer text, and
 * those tokens count against `max_tokens`. A cap tuned for a 3-sentence spoken
 * answer can therefore be exhausted before the first visible character, which
 * returns an empty completion rather than a short one. Deliberately reuses the
 * same family test as [omitsTemperature] so the two stay in step.
 */
internal fun omitsTokenCap(kind: ProviderKind, model: String): Boolean =
    omitsTemperature(kind, model)

/**
 * Default answer cap. Generous relative to `maxResponseSentences` (1-10) on
 * purpose: the sentence count is a style request, and clipping a well-formed
 * answer mid-word is worse than letting a verbose one through. Sized to comfort
 * a long 10-sentence answer, not to enforce brevity.
 */
internal const val DEFAULT_MAX_TOKENS = 400

/**
 * Token budget for [AnswerProvider.classify] calls. A classification response
 * is a short list of questions (or the literal "NONE"), never prose, so this
 * is intentionally far smaller than [DEFAULT_MAX_TOKENS] — this is the "tiny
 * token budget" cost control for the always-on question-detection path.
 */
internal const val CLASSIFY_MAX_TOKENS = 120

/** Builds the [AnswerResponse], preferring the model the API reports. */
internal fun answerFrom(
    root: JsonObject,
    text: String,
    kind: ProviderKind,
    fallbackModel: String,
): AnswerResponse {
    if (text.isEmpty()) throw ProviderEmptyResponseException(kind)
    val reportedModel = root["model"]?.jsonPrimitive?.contentOrNullSafe()?.trim()
    return AnswerResponse(
        text = text,
        providerKind = kind,
        model = if (reportedModel.isNullOrEmpty()) fallbackModel else reportedModel,
    )
}

/**
 * Base URLs per provider. DeepSeek/Qwen/Zhipu all speak the OpenAI
 * `/chat/completions` dialect, so they share [OpenAiCompatibleProvider].
 */
object ProviderEndpoints {
    const val OPENAI = "https://api.openai.com/v1"
    const val ANTHROPIC = "https://api.anthropic.com/v1"
    const val DEEPSEEK = "https://api.deepseek.com/v1"
    const val QWEN = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    const val ZHIPU = "https://open.bigmodel.cn/api/paas/v4"

    fun forKind(kind: ProviderKind): String = when (kind) {
        ProviderKind.OPENAI -> OPENAI
        ProviderKind.ANTHROPIC -> ANTHROPIC
        ProviderKind.DEEPSEEK -> DEEPSEEK
        ProviderKind.QWEN -> QWEN
        ProviderKind.ZHIPU -> ZHIPU
        ProviderKind.DETERMINISTIC -> OPENAI
    }
}

/**
 * Keyless provider used when no API key is stored, and as the deterministic
 * fixture for tests. Ported from Swift `DeterministicAnswerProvider`.
 */
class DeterministicProvider(
    override val kind: ProviderKind = ProviderKind.DETERMINISTIC,
    override val model: String = "deterministic-native",
) : AnswerProvider {

    /**
     * Non-streaming by nature (there is no model to stream from), so the whole
     * canned answer is emitted as a single delta — the degenerate case the
     * contract allows, which keeps every streaming caller working keyless.
     */
    override suspend fun answer(request: AnswerRequest, onDelta: ((String) -> Unit)?): AnswerResponse {
        val text = makeAnswer(request)
        onDelta?.invoke(text)
        return AnswerResponse(text = text, providerKind = kind, model = model)
    }

    private fun makeAnswer(request: AnswerRequest): String {
        val memory = request.conversationContext.trim()
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val memoryPrefix = if (memory.isEmpty()) "" else "Remembering ${memory.last()}. "

        // On-demand "answer from the recent conversation" needs a real model;
        // say so instead of returning the generic canned line as if it had.
        if (PromptBuilder.isRecentContextRequest(request)) {
            return "Connect an AI provider key to answer from the conversation. " +
                (memory.lastOrNull()?.let { "Last heard: $it" } ?: "")
        }

        if (request.skill.name.equals("dsa", ignoreCase = true)) {
            return memoryPrefix +
                "Use an algorithmic answer with time complexity, space complexity, and edge cases."
        }

        val knowledge = request.knowledgeContext.map { it.trim() }.filter { it.isNotEmpty() }
        if (knowledge.isNotEmpty()) {
            return memoryPrefix + "Use the project context: ${knowledge.joinToString(", ")}."
        }

        // ConversationMode no longer implies output structure (that regressed
        // to skill-agnostic STAR text here too, the same defect this mode/skill
        // precedence fix addresses in PromptBuilder) — ACTIVE gets one neutral
        // canned line regardless of which skill is selected.
        return memoryPrefix + when (request.mode) {
            ConversationMode.ACTIVE ->
                "An LLM uses transformer attention to predict useful next tokens from context."

            ConversationMode.PASSIVE ->
                "Answer passively and briefly with the useful point only."
        }
    }
}

/**
 * OpenAI-dialect chat completions. Base class for OpenAI, DeepSeek, Qwen and
 * Zhipu — they differ only in base URL, default model and reported [kind].
 */
open class OpenAiCompatibleProvider(
    private val apiKey: String,
    model: String,
    override val kind: ProviderKind = ProviderKind.OPENAI,
    private val baseUrl: String = ProviderEndpoints.OPENAI,
    private val client: OkHttpClient = defaultClient,
    private val temperature: Double = 0.2,
    /**
     * Upper bound on answer length. Bounds latency as much as cost: an answer
     * for a live conversation is read on a 5-line HUD, so an unbounded reply is
     * both slower to arrive and unusable when it does. Anthropic already sent a
     * cap; the OpenAI dialect sent none, so `maxResponseSentences` was only ever
     * a prose request the model could ignore.
     */
    private val maxTokens: Int = DEFAULT_MAX_TOKENS,
) : AnswerProvider {

    override val model: String = model.trim().ifEmpty { defaultModelFor(kind) }

    override suspend fun answer(
        request: AnswerRequest,
        onDelta: ((String) -> Unit)?,
    ): AnswerResponse = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)
        val url = baseUrl.trimEnd('/') + "/chat/completions"
        val headers = authHeadersFor(kind, apiKey)
        if (onDelta == null) {
            val root = postJsonForObject(
                client = client,
                url = url,
                headers = headers,
                body = buildBody(request),
                kind = kind,
            )
            return@withContext answerFrom(root, extractText(root), kind, model)
        }
        streamAnswer(url, headers, request, onDelta)
    }

    /**
     * `stream: true` + SSE. Each frame is one `chat.completion.chunk` whose
     * `choices[0].delta.content` holds the new text; the stream ends with a
     * literal `data: [DONE]`, which is not JSON and must be checked first.
     *
     * The model id is taken from whichever chunk reports one (they all do, but
     * only the first is guaranteed), so the terminal [AnswerResponse] carries
     * the same server-reported model the buffered path would have.
     */
    private suspend fun streamAnswer(
        url: String,
        headers: Map<String, String>,
        request: AnswerRequest,
        onDelta: (String) -> Unit,
    ): AnswerResponse {
        val accumulated = StringBuilder()
        var reportedModel: String? = null
        streamSse(
            client = client,
            url = url,
            headers = headers,
            body = buildBody(request, stream = true),
            kind = kind,
        ) { event ->
            if (event.data == SSE_DONE) return@streamSse false
            val chunk = runCatching { helixJson.parseToJsonElement(event.data).jsonObject }.getOrNull()
                ?: return@streamSse true // tolerate a keep-alive or malformed frame
            if (reportedModel == null) {
                reportedModel = chunk["model"]?.jsonPrimitive?.contentOrNullSafe()?.trim()
                    ?.takeIf { it.isNotEmpty() }
            }
            val delta = chunk["choices"]?.jsonArray?.firstOrNull()
                ?.jsonObject?.get("delta")
                ?.jsonObject?.get("content")
                ?.jsonPrimitive?.contentOrNullSafe()
            if (!delta.isNullOrEmpty()) {
                accumulated.append(delta)
                onDelta(delta)
            }
            true
        }
        val text = accumulated.toString().trim()
        if (text.isEmpty()) throw ProviderEmptyResponseException(kind)
        return AnswerResponse(
            text = text,
            providerKind = kind,
            model = reportedModel ?: model,
        )
    }

    internal fun buildBody(request: AnswerRequest, stream: Boolean = false): JsonObject {
        val prompt = PromptBuilder.build(request)
        return buildJsonObject {
            put("model", model)
            if (!omitsTemperature(kind, model)) put("temperature", temperature)
            // Reasoning models bill their hidden thinking against the same
            // budget, so a cap sized for prose can be consumed entirely by
            // reasoning and return an EMPTY completion. Omitted for them for
            // the same reason `temperature` is — see omitsTemperature.
            if (!omitsTokenCap(kind, model)) put("max_tokens", maxTokens)
            if (stream) put("stream", true)
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", "system")
                    put("content", prompt.system)
                })
                add(buildJsonObject {
                    put("role", "user")
                    put("content", prompt.user)
                })
            })
        }
    }

    /**
     * Raw classification call for [LlmQuestionDetector]: a single user
     * message, no system prompt, and a small fixed token budget completely
     * separate from [maxTokens]/[buildBody] (this does not touch the answer
     * path's max_tokens logic at all). Never streamed — the classifier wants
     * one compact buffered response.
     */
    override suspend fun classify(prompt: String): String = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)
        val url = baseUrl.trimEnd('/') + "/chat/completions"
        val headers = authHeadersFor(kind, apiKey)
        val body = buildJsonObject {
            put("model", model)
            if (!omitsTemperature(kind, model)) put("temperature", 0.0)
            if (!omitsTokenCap(kind, model)) put("max_tokens", CLASSIFY_MAX_TOKENS)
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", "user")
                    put("content", prompt)
                })
            })
        }
        val root = postJsonForObject(client = client, url = url, headers = headers, body = body, kind = kind)
        extractText(root)
    }

    private fun extractText(root: JsonObject): String =
        root["choices"]?.jsonArray?.firstOrNull()
            ?.jsonObject?.get("message")
            ?.jsonObject?.get("content")
            ?.jsonPrimitive?.contentOrNullSafe()
            ?.trim()
            .orEmpty()

    companion object {
        /**
         * Shared client with explicit timeouts. OkHttp's 10 s read default
         * is too short for a chat completion under load; 60 s covers slow
         * reasoning models without leaving a dead socket open forever.
         */
        val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build()
        }

        /**
         * Single source of truth for the default model: the Domain settings
         * table, falling back to the catalog's curated list (which is itself
         * derived from the same table) for kinds the table does not list.
         */
        fun defaultModelFor(kind: ProviderKind): String =
            HelixSettings.defaultProviders()[kind.name]?.smartModel
                ?: ModelCatalog.fallbackModels(kind).first()
    }
}

/** Anthropic Messages API: `POST /v1/messages`, `x-api-key` + `anthropic-version`. */
class AnthropicProvider(
    private val apiKey: String,
    model: String,
    private val baseUrl: String = ProviderEndpoints.ANTHROPIC,
    private val client: OkHttpClient = OpenAiCompatibleProvider.defaultClient,
    private val maxTokens: Int = 1024,
    private val temperature: Double = 0.2,
) : AnswerProvider {

    override val kind: ProviderKind = ProviderKind.ANTHROPIC
    override val model: String = model.trim().ifEmpty { DEFAULT_MODEL }

    override suspend fun answer(
        request: AnswerRequest,
        onDelta: ((String) -> Unit)?,
    ): AnswerResponse = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)
        val url = baseUrl.trimEnd('/') + "/messages"
        val headers = authHeadersFor(kind, apiKey)
        if (onDelta == null) {
            val root = postJsonForObject(
                client = client,
                url = url,
                headers = headers,
                body = buildBody(request),
                kind = kind,
            )
            return@withContext answerFrom(root, extractText(root), kind, model)
        }
        streamAnswer(url, headers, request, onDelta)
    }

    /**
     * `stream: true` + SSE, Anthropic Messages dialect. Text arrives as
     * `content_block_delta` frames carrying `delta.text`; `message_start`
     * reports the model; `message_stop` ends the stream. `ping` frames and any
     * unknown type are ignored rather than treated as an error.
     */
    private suspend fun streamAnswer(
        url: String,
        headers: Map<String, String>,
        request: AnswerRequest,
        onDelta: (String) -> Unit,
    ): AnswerResponse {
        val accumulated = StringBuilder()
        var reportedModel: String? = null
        streamSse(
            client = client,
            url = url,
            headers = headers,
            body = buildBody(request, stream = true),
            kind = kind,
        ) { event ->
            val frame = runCatching { helixJson.parseToJsonElement(event.data).jsonObject }.getOrNull()
                ?: return@streamSse true
            when (frame["type"]?.jsonPrimitive?.contentOrNullSafe()) {
                "message_start" -> {
                    reportedModel = frame["message"]?.jsonObject
                        ?.get("model")?.jsonPrimitive?.contentOrNullSafe()?.trim()
                        ?.takeIf { it.isNotEmpty() }
                }

                "content_block_delta" -> {
                    val delta = frame["delta"]?.jsonObject
                        ?.get("text")?.jsonPrimitive?.contentOrNullSafe()
                    if (!delta.isNullOrEmpty()) {
                        accumulated.append(delta)
                        onDelta(delta)
                    }
                }

                "message_stop" -> return@streamSse false
            }
            true
        }
        val text = accumulated.toString().trim()
        if (text.isEmpty()) throw ProviderEmptyResponseException(kind)
        return AnswerResponse(
            text = text,
            providerKind = kind,
            model = reportedModel ?: model,
        )
    }

    /**
     * Raw classification call for [LlmQuestionDetector] — see the
     * [OpenAiCompatibleProvider.classify] override for why this bypasses
     * [PromptBuilder] and [buildBody]/[maxTokens] entirely. Never streamed.
     */
    override suspend fun classify(prompt: String): String = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)
        val url = baseUrl.trimEnd('/') + "/messages"
        val headers = authHeadersFor(kind, apiKey)
        val body = buildJsonObject {
            put("model", model)
            put("max_tokens", CLASSIFY_MAX_TOKENS)
            put("temperature", 0.0)
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", "user")
                    put("content", prompt)
                })
            })
        }
        val root = postJsonForObject(client = client, url = url, headers = headers, body = body, kind = kind)
        extractText(root)
    }

    internal fun buildBody(request: AnswerRequest, stream: Boolean = false): JsonObject {
        val prompt = PromptBuilder.build(request)
        return buildJsonObject {
            put("model", model)
            put("max_tokens", maxTokens)
            put("temperature", temperature)
            if (stream) put("stream", true)
            put("system", prompt.system)
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", "user")
                    put("content", prompt.user)
                })
            })
        }
    }

    private fun extractText(root: JsonObject): String =
        (root["content"]?.jsonArray ?: emptyList<JsonElement>())
            .mapNotNull { element ->
                val block = element.jsonObject
                if (block["type"]?.jsonPrimitive?.contentOrNullSafe() == "text") {
                    block["text"]?.jsonPrimitive?.contentOrNullSafe()
                } else {
                    null
                }
            }
            .joinToString("")
            .trim()

    companion object {
        const val ANTHROPIC_VERSION = "2023-06-01"

        /** Derived from the Domain defaults so the two tables cannot drift. */
        val DEFAULT_MODEL: String
            get() = OpenAiCompatibleProvider.defaultModelFor(ProviderKind.ANTHROPIC)
    }
}

private fun JsonPrimitive.contentOrNullSafe(): String? = if (this is JsonNull) null else content
