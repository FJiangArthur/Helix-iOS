package com.artjiang.helix.ai

import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ProvidersTest {

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun baseUrl(): String = server.url("/v1").toString().trimEnd('/')

    private fun request(
        question: String = "What is RAG?",
        mode: ConversationMode = ConversationMode.GENERAL,
    ) = AnswerRequest(
        question = question,
        mode = mode,
        skill = ActiveSkill(),
        maxResponseSentences = 3,
    )

    // MARK: OpenAI-compatible

    @Test
    fun `openai provider posts correct path headers and body`() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"model":"gpt-4.1","choices":[{"message":{"content":"  RAG grounds answers.  "}}]}""",
            ),
        )

        val provider = OpenAiCompatibleProvider(
            apiKey = "sk-test",
            model = "gpt-4.1",
            kind = ProviderKind.OPENAI,
            baseUrl = baseUrl(),
        )
        val response = provider.answer(request())

        val recorded = server.takeRequest()
        assertEquals("POST", recorded.method)
        assertEquals("/v1/chat/completions", recorded.path)
        assertEquals("Bearer sk-test", recorded.getHeader("Authorization"))
        assertTrue(recorded.getHeader("Content-Type").orEmpty().startsWith("application/json"))

        val body = helixJson.parseToJsonElement(recorded.body.readUtf8()).jsonObject
        assertEquals("gpt-4.1", body["model"]?.jsonPrimitive?.content)
        val messages = body["messages"]!!.jsonArray
        assertEquals(2, messages.size)
        assertEquals("system", messages[0].jsonObject["role"]?.jsonPrimitive?.content)
        assertEquals("user", messages[1].jsonObject["role"]?.jsonPrimitive?.content)
        assertTrue(
            messages[1].jsonObject["content"]!!.jsonPrimitive.content.contains("What is RAG?"),
        )

        assertEquals("RAG grounds answers.", response.text)
        assertEquals(ProviderKind.OPENAI, response.providerKind)
        assertEquals("gpt-4.1", response.model)
    }

    @Test
    fun `openai compatible base carries provider kind for deepseek`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))

        val provider = OpenAiCompatibleProvider(
            apiKey = "ds-key",
            model = "deepseek-chat",
            kind = ProviderKind.DEEPSEEK,
            baseUrl = baseUrl(),
        )
        val response = provider.answer(request())

        assertEquals(ProviderKind.DEEPSEEK, response.providerKind)
        // Model falls back to the configured id when the payload omits it.
        assertEquals("deepseek-chat", response.model)
    }

    @Test
    fun `interview mode system prompt reaches the wire`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))

        OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl())
            .answer(request(mode = ConversationMode.INTERVIEW))

        val body = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        val system = body["messages"]!!.jsonArray[0].jsonObject["content"]!!.jsonPrimitive.content
        assertTrue(system.contains("STAR"))
        assertTrue(system.contains("you could say"))
    }

    @Test
    fun `openai http error maps to typed exception with status and body`() = runTest {
        server.enqueue(
            MockResponse().setResponseCode(429)
                .setBody("""{"error":{"message":"rate limit"}}"""),
        )

        val provider = OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl())
        val error = runCatching { provider.answer(request()) }.exceptionOrNull()

        assertTrue(error is ProviderHttpException)
        error as ProviderHttpException
        assertEquals(429, error.statusCode)
        assertEquals(ProviderKind.OPENAI, error.providerKind)
        assertTrue(error.bodySnippet.contains("rate limit"))
    }

    @Test
    fun `empty openai content maps to empty response exception`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"   "}}]}"""))
        val provider = OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl())
        val error = runCatching { provider.answer(request()) }.exceptionOrNull()
        assertTrue(error is ProviderEmptyResponseException)
    }

    @Test
    fun `missing key throws before any network call`() = runTest {
        val provider = OpenAiCompatibleProvider(apiKey = "  ", model = "gpt-4.1", baseUrl = baseUrl())
        val error = runCatching { provider.answer(request()) }.exceptionOrNull()
        assertTrue(error is MissingApiKeyException)
        assertEquals(0, server.requestCount)
    }

    // MARK: Anthropic

    @Test
    fun `anthropic provider posts messages with required headers and max_tokens`() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"model":"claude-sonnet-4-5","content":[{"type":"text","text":"RAG grounds answers."}]}""",
            ),
        )

        val provider = AnthropicProvider(
            apiKey = "sk-ant",
            model = "claude-sonnet-4-5",
            baseUrl = baseUrl(),
        )
        val response = provider.answer(request())

        val recorded = server.takeRequest()
        assertEquals("POST", recorded.method)
        assertEquals("/v1/messages", recorded.path)
        assertEquals("sk-ant", recorded.getHeader("x-api-key"))
        assertEquals("2023-06-01", recorded.getHeader("anthropic-version"))

        val body = helixJson.parseToJsonElement(recorded.body.readUtf8()).jsonObject
        assertEquals("claude-sonnet-4-5", body["model"]?.jsonPrimitive?.content)
        assertNotNull("max_tokens is required by the Messages API", body["max_tokens"])
        assertTrue(body["max_tokens"]!!.jsonPrimitive.content.toInt() > 0)
        // System prompt is a top-level field, not a message.
        assertTrue(body["system"]!!.jsonPrimitive.content.contains("Helix"))
        assertEquals(1, body["messages"]!!.jsonArray.size)
        assertEquals("user", body["messages"]!!.jsonArray[0].jsonObject["role"]?.jsonPrimitive?.content)

        assertEquals("RAG grounds answers.", response.text)
        assertEquals(ProviderKind.ANTHROPIC, response.providerKind)
        assertEquals("claude-sonnet-4-5", response.model)
    }

    @Test
    fun `anthropic concatenates text blocks and skips non text blocks`() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"One. "},{"type":"text","text":"Two."}]}""",
            ),
        )
        val provider = AnthropicProvider(apiKey = "k", model = "claude-haiku-4-5", baseUrl = baseUrl())
        assertEquals("One. Two.", provider.answer(request()).text)
    }

    @Test
    fun `anthropic http error maps to typed exception`() = runTest {
        server.enqueue(
            MockResponse().setResponseCode(401)
                .setBody("""{"error":{"type":"authentication_error"}}"""),
        )
        val provider = AnthropicProvider(apiKey = "bad", model = "claude-haiku-4-5", baseUrl = baseUrl())
        val error = runCatching { provider.answer(request()) }.exceptionOrNull()

        assertTrue(error is ProviderHttpException)
        error as ProviderHttpException
        assertEquals(401, error.statusCode)
        assertEquals(ProviderKind.ANTHROPIC, error.providerKind)
        assertTrue(error.bodySnippet.contains("authentication_error"))
    }

    @Test
    fun `anthropic default model is a valid id`() {
        val provider = AnthropicProvider(apiKey = "k", model = "  ")
        assertEquals("claude-haiku-4-5", provider.model)
    }

    // MARK: Deterministic

    @Test
    fun `deterministic provider answers an llm question with the transformer sentence`() = runTest {
        val response = DeterministicProvider().answer(request(question = "What is an LLM?"))
        assertEquals(
            "An LLM uses transformer attention to predict useful next tokens from context.",
            response.text,
        )
        assertEquals(ProviderKind.DETERMINISTIC, response.providerKind)
    }

    @Test
    fun `deterministic provider varies by mode`() = runTest {
        val provider = DeterministicProvider()
        assertTrue(
            provider.answer(request(mode = ConversationMode.INTERVIEW)).text
                .contains("situation, action, result"),
        )
        assertTrue(
            provider.answer(request(mode = ConversationMode.PASSIVE)).text
                .contains("Answer passively"),
        )
    }

    @Test
    fun `deterministic provider prefixes session memory and uses knowledge context`() = runTest {
        val response = DeterministicProvider().answer(
            AnswerRequest(
                question = "What is the deadline?",
                mode = ConversationMode.GENERAL,
                skill = ActiveSkill(),
                maxResponseSentences = 3,
                conversationContext = "Heard: kickoff was Monday\nHeard: launch is Friday",
                knowledgeContext = listOf("Launch is Friday"),
            ),
        )
        assertTrue(response.text.startsWith("Remembering Heard: launch is Friday."))
        assertTrue(response.text.contains("Use the project context: Launch is Friday."))
    }

    @Test
    fun `deterministic provider honors the dsa skill`() = runTest {
        val response = DeterministicProvider().answer(
            AnswerRequest(
                question = "Reverse a linked list",
                mode = ConversationMode.GENERAL,
                skill = ActiveSkill(name = "dsa", prompt = ""),
                maxResponseSentences = 3,
            ),
        )
        assertTrue(response.text.contains("time complexity, space complexity, and edge cases"))
    }

    // MARK: Factory

    @Test
    fun `factory falls back to deterministic without a key`() {
        val provider = ProviderFactory(EmptyKeyStore)
            .make(HelixSettings(activeProvider = "OPENAI"))
        assertTrue(provider is DeterministicProvider)
        // Kind is preserved so the UI can still show the intended provider.
        assertEquals(ProviderKind.OPENAI, provider.kind)
    }

    @Test
    fun `factory builds openai compatible providers for the openai family`() {
        val keys = MapKeyStore(
            mapOf("OPENAI" to "k", "DEEPSEEK" to "k", "QWEN" to "k", "ZHIPU" to "k"),
        )
        val factory = ProviderFactory(keys)

        for (kind in listOf(
            ProviderKind.OPENAI, ProviderKind.DEEPSEEK, ProviderKind.QWEN, ProviderKind.ZHIPU,
        )) {
            val provider = factory.make(HelixSettings(activeProvider = kind.name))
            assertTrue("$kind should use the OpenAI dialect", provider is OpenAiCompatibleProvider)
            assertEquals(kind, provider.kind)
        }
    }

    @Test
    fun `factory builds an anthropic provider with the configured smart model`() {
        val provider = ProviderFactory(MapKeyStore(mapOf("ANTHROPIC" to "sk-ant")))
            .make(HelixSettings(activeProvider = "ANTHROPIC"))
        assertTrue(provider is AnthropicProvider)
        assertEquals("claude-sonnet-4-5", provider.model)
    }

    @Test
    fun `factory treats a blank key as no key`() {
        val provider = ProviderFactory(MapKeyStore(mapOf("OPENAI" to "   ")))
            .make(HelixSettings(activeProvider = "OPENAI"))
        assertTrue(provider is DeterministicProvider)
    }

    @Test
    fun `factory endpoints match the documented base urls`() {
        assertEquals("https://api.openai.com/v1", ProviderEndpoints.forKind(ProviderKind.OPENAI))
        assertEquals("https://api.anthropic.com/v1", ProviderEndpoints.forKind(ProviderKind.ANTHROPIC))
        assertEquals("https://api.deepseek.com/v1", ProviderEndpoints.forKind(ProviderKind.DEEPSEEK))
        assertEquals(
            "https://dashscope.aliyuncs.com/compatible-mode/v1",
            ProviderEndpoints.forKind(ProviderKind.QWEN),
        )
        assertEquals("https://open.bigmodel.cn/api/paas/v4", ProviderEndpoints.forKind(ProviderKind.ZHIPU))
    }

    @Test
    fun `factory routes an unknown provider name to deterministic`() {
        val provider = ProviderFactory(MapKeyStore(mapOf("OPENAI" to "k")))
            .make(HelixSettings(activeProvider = "NOT_A_PROVIDER"))
        assertTrue(provider is DeterministicProvider)
    }
}
