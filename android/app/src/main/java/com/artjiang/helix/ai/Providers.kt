package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.Dispatchers
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

    override suspend fun answer(request: AnswerRequest): AnswerResponse =
        AnswerResponse(text = makeAnswer(request), providerKind = kind, model = model)

    private fun makeAnswer(request: AnswerRequest): String {
        val memory = request.conversationContext.trim()
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val memoryPrefix = if (memory.isEmpty()) "" else "Remembering ${memory.last()}. "

        if (request.skill.name.equals("dsa", ignoreCase = true)) {
            return memoryPrefix +
                "Use an algorithmic answer with time complexity, space complexity, and edge cases."
        }

        val knowledge = request.knowledgeContext.map { it.trim() }.filter { it.isNotEmpty() }
        if (knowledge.isNotEmpty()) {
            return memoryPrefix + "Use the project context: ${knowledge.joinToString(", ")}."
        }

        return memoryPrefix + when (request.mode) {
            ConversationMode.INTERVIEW ->
                "Answer directly with situation, action, result, and one measurable impact."

            ConversationMode.PASSIVE ->
                "Answer passively and briefly with the useful point only."

            ConversationMode.GENERAL ->
                "An LLM uses transformer attention to predict useful next tokens from context."
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
) : AnswerProvider {

    override val model: String = model.trim().ifEmpty { defaultModelFor(kind) }

    override suspend fun answer(request: AnswerRequest): AnswerResponse = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)

        val httpRequest = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/chat/completions")
            .addHeader("Authorization", "Bearer ${apiKey.trim()}")
            .addHeader("Content-Type", "application/json")
            .post(buildBody(request).toString().toRequestBody(JSON_MEDIA_TYPE))
            .build()

        client.newCall(httpRequest).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ProviderHttpException(kind, response.code, snippet(body))
            }
            parse(body)
        }
    }

    internal fun buildBody(request: AnswerRequest): JsonObject {
        val prompt = PromptBuilder.build(request)
        return buildJsonObject {
            put("model", model)
            put("temperature", temperature)
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

    private fun parse(body: String): AnswerResponse {
        val root = runCatching { helixJson.parseToJsonElement(body).jsonObject }.getOrNull()
            ?: throw ProviderEmptyResponseException(kind)
        val text = root["choices"]?.jsonArray?.firstOrNull()
            ?.jsonObject?.get("message")
            ?.jsonObject?.get("content")
            ?.jsonPrimitive?.contentOrNullSafe()
            ?.trim()
            .orEmpty()
        if (text.isEmpty()) throw ProviderEmptyResponseException(kind)
        val reportedModel = root["model"]?.jsonPrimitive?.contentOrNullSafe()?.trim()
        return AnswerResponse(
            text = text,
            providerKind = kind,
            model = if (reportedModel.isNullOrEmpty()) model else reportedModel,
        )
    }

    companion object {
        val defaultClient: OkHttpClient by lazy { OkHttpClient() }

        fun defaultModelFor(kind: ProviderKind): String = when (kind) {
            ProviderKind.OPENAI, ProviderKind.DETERMINISTIC -> "gpt-4.1-mini"
            ProviderKind.DEEPSEEK -> "deepseek-chat"
            ProviderKind.QWEN -> "qwen-turbo"
            ProviderKind.ZHIPU -> "glm-4-flash"
            ProviderKind.ANTHROPIC -> "claude-haiku-4-5"
        }
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

    override suspend fun answer(request: AnswerRequest): AnswerResponse = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw MissingApiKeyException(kind)

        val httpRequest = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/messages")
            .addHeader("x-api-key", apiKey.trim())
            .addHeader("anthropic-version", ANTHROPIC_VERSION)
            .addHeader("Content-Type", "application/json")
            .post(buildBody(request).toString().toRequestBody(JSON_MEDIA_TYPE))
            .build()

        client.newCall(httpRequest).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ProviderHttpException(kind, response.code, snippet(body))
            }
            parse(body)
        }
    }

    internal fun buildBody(request: AnswerRequest): JsonObject {
        val prompt = PromptBuilder.build(request)
        return buildJsonObject {
            put("model", model)
            put("max_tokens", maxTokens)
            put("temperature", temperature)
            put("system", prompt.system)
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", "user")
                    put("content", prompt.user)
                })
            })
        }
    }

    private fun parse(body: String): AnswerResponse {
        val root = runCatching { helixJson.parseToJsonElement(body).jsonObject }.getOrNull()
            ?: throw ProviderEmptyResponseException(kind)
        val text = (root["content"]?.jsonArray ?: emptyList<JsonElement>())
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
        if (text.isEmpty()) throw ProviderEmptyResponseException(kind)
        val reportedModel = root["model"]?.jsonPrimitive?.contentOrNullSafe()?.trim()
        return AnswerResponse(
            text = text,
            providerKind = kind,
            model = if (reportedModel.isNullOrEmpty()) model else reportedModel,
        )
    }

    companion object {
        const val ANTHROPIC_VERSION = "2023-06-01"
        const val DEFAULT_MODEL = "claude-haiku-4-5"
    }
}

private fun JsonPrimitive.contentOrNullSafe(): String? = if (this is JsonNull) null else content
