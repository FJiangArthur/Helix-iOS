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
import org.junit.Assert.assertNull
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
        mode: ConversationMode = ConversationMode.ACTIVE,
        skill: ActiveSkill = ActiveSkill(),
    ) = AnswerRequest(
        question = question,
        mode = mode,
        skill = skill,
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
    fun `behavioral skill system prompt reaches the wire`() = runTest {
        // STAR structure is now carried by the `behavioral` skill, not by
        // ConversationMode — regression coverage for the bug where selecting
        // Social Confidence still produced STAR interview answers because
        // ConversationMode.INTERVIEW's structural directive outranked the
        // skill's tonal one. See PromptBuilderTest for the system-prompt-level
        // assertions on both sides of this fix.
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))

        OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl())
            .answer(
                request(
                    mode = ConversationMode.ACTIVE,
                    skill = ActiveSkill(
                        value = "behavioral",
                        label = "Behavioral Interview",
                        prompt = "Produce a directly speakable first-person answer structured " +
                            "with the STAR framework (situation, task, action, result) and close " +
                            "with one measurable impact.",
                    ),
                ),
            )

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
    fun `anthropic default model derives from the domain table`() {
        val provider = AnthropicProvider(apiKey = "k", model = "  ")
        assertEquals("claude-sonnet-4-5", provider.model)
        assertEquals(
            HelixSettings.defaultProviders()["ANTHROPIC"]!!.smartModel,
            AnthropicProvider.DEFAULT_MODEL,
        )
    }

    // MARK: Transport and defaults

    @Test
    fun `reasoning models omit temperature and everything else keeps it`() {
        val matrix = listOf(
            Triple(ProviderKind.OPENAI, "gpt-5", true),
            Triple(ProviderKind.OPENAI, "gpt-5-mini", true),
            Triple(ProviderKind.OPENAI, "GPT-5.1", true),
            Triple(ProviderKind.OPENAI, "o1", true),
            Triple(ProviderKind.OPENAI, "o3-mini", true),
            Triple(ProviderKind.OPENAI, "o4-mini", true),
            Triple(ProviderKind.OPENAI, "gpt-4.1", false),
            Triple(ProviderKind.OPENAI, "gpt-4o", false),
            Triple(ProviderKind.OPENAI, "chatgpt-4o-latest", false),
            Triple(ProviderKind.OPENAI, "omni-chat", false),
            Triple(ProviderKind.DEEPSEEK, "deepseek-v4-flash", false),
            Triple(ProviderKind.DEEPSEEK, "deepseek-reasoner", false),
            Triple(ProviderKind.QWEN, "qwen-max", false),
            Triple(ProviderKind.ZHIPU, "glm-4", false),
        )
        for ((kind, model, omitted) in matrix) {
            assertEquals("$kind/$model", omitted, omitsTemperature(kind, model))
            val body = OpenAiCompatibleProvider(apiKey = "k", model = model, kind = kind, baseUrl = baseUrl())
                .buildBody(request())
            assertEquals("$kind/$model body", omitted, body["temperature"] == null)
        }
    }

    @Test
    fun `a token cap bounds normal models and is omitted for reasoning models`() {
        // Latency, not just cost: an unbounded answer on a 5-line HUD is both
        // slower to arrive and unusable. maxResponseSentences is prose the model
        // may ignore, so the cap is the only real bound.
        val capped = OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl())
            .buildBody(request())
        assertEquals(
            DEFAULT_MAX_TOKENS,
            capped["max_tokens"]?.jsonPrimitive?.content?.toInt(),
        )

        // Reasoning models bill hidden thinking against the same budget, so a
        // prose-sized cap can be spent before the first visible character and
        // return an EMPTY completion. Same family test as omitsTemperature.
        for (model in listOf("gpt-5", "gpt-5.5-2026-04-23", "o1", "o3-mini")) {
            val body = OpenAiCompatibleProvider(apiKey = "k", model = model, baseUrl = baseUrl())
                .buildBody(request())
            assertNull("$model must not carry a token cap", body["max_tokens"])
            assertTrue("$model must be recognised", omitsTokenCap(ProviderKind.OPENAI, model))
        }
    }

    @Test
    fun `gpt-5 request body on the wire carries no temperature`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))

        OpenAiCompatibleProvider(apiKey = "k", model = "gpt-5", baseUrl = baseUrl()).answer(request())
        val reasoning = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertNull(reasoning["temperature"])
        assertEquals("gpt-5", reasoning["model"]?.jsonPrimitive?.content)

        OpenAiCompatibleProvider(apiKey = "k", model = "gpt-4.1", baseUrl = baseUrl()).answer(request())
        val classic = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals(0.2, classic["temperature"]!!.jsonPrimitive.content.toDouble(), 1e-9)
    }

    @Test
    fun `default client waits 60 s for a reply`() {
        val client = OpenAiCompatibleProvider.defaultClient
        assertEquals(15_000, client.connectTimeoutMillis)
        assertEquals(60_000, client.readTimeoutMillis)
        assertEquals(30_000, client.writeTimeoutMillis)
    }

    @Test
    fun `default model comes from the domain table for every provider`() {
        for ((name, config) in HelixSettings.defaultProviders()) {
            assertEquals(config.smartModel, OpenAiCompatibleProvider.defaultModelFor(ProviderKind.valueOf(name)))
        }
        assertEquals("deepseek-v4-flash", OpenAiCompatibleProvider.defaultModelFor(ProviderKind.DEEPSEEK))
        assertEquals("gpt-4.1", OpenAiCompatibleProvider.defaultModelFor(ProviderKind.DETERMINISTIC))
        assertEquals("gpt-4.1", OpenAiCompatibleProvider(apiKey = "k", model = " ").model)
    }

    @Test
    fun `auth headers match each provider dialect`() {
        assertEquals(mapOf("Authorization" to "Bearer sk"), authHeadersFor(ProviderKind.OPENAI, " sk "))
        assertEquals(mapOf("Authorization" to "Bearer ds"), authHeadersFor(ProviderKind.DEEPSEEK, "ds"))
        assertEquals(mapOf("Authorization" to "Bearer qw"), authHeadersFor(ProviderKind.QWEN, "qw"))
        assertEquals(mapOf("Authorization" to "Bearer zp"), authHeadersFor(ProviderKind.ZHIPU, "zp"))
        assertEquals(
            mapOf("x-api-key" to "ant", "anthropic-version" to "2023-06-01"),
            authHeadersFor(ProviderKind.ANTHROPIC, "ant"),
        )
    }

    @Test
    fun `getJsonForObject maps status and body like the post helper`() = runTest {
        server.enqueue(MockResponse().setBody("""{"data":[]}"""))
        server.enqueue(MockResponse().setResponseCode(500).setBody("boom"))
        server.enqueue(MockResponse().setBody("[]"))

        val ok = getJsonForObject(OpenAiCompatibleProvider.defaultClient, baseUrl() + "/models", mapOf("X-T" to "1"), ProviderKind.OPENAI)
        assertNotNull(ok["data"])
        val recorded = server.takeRequest()
        assertEquals("GET", recorded.method)
        assertEquals("1", recorded.getHeader("X-T"))

        val http = runCatching {
            getJsonForObject(OpenAiCompatibleProvider.defaultClient, baseUrl() + "/models", emptyMap(), ProviderKind.QWEN)
        }.exceptionOrNull()
        assertTrue(http is ProviderHttpException)
        assertEquals(500, (http as ProviderHttpException).statusCode)
        assertEquals(ProviderKind.QWEN, http.providerKind)

        val notObject = runCatching {
            getJsonForObject(OpenAiCompatibleProvider.defaultClient, baseUrl() + "/models", emptyMap(), ProviderKind.OPENAI)
        }.exceptionOrNull()
        assertTrue(notObject is ProviderEmptyResponseException)
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
        // Mode no longer implies output structure (that's the skill's job), so
        // ACTIVE gets one neutral canned line regardless of skill; only PASSIVE
        // differs.
        val provider = DeterministicProvider()
        assertTrue(
            provider.answer(request(mode = ConversationMode.ACTIVE)).text
                .contains("transformer attention"),
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
                mode = ConversationMode.ACTIVE,
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
                mode = ConversationMode.ACTIVE,
                skill = ActiveSkill(value = "dsa", label = "Data Structures & Algorithms", prompt = ""),
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
        // The fallback reports itself truthfully: stamping the configured kind
        // made the UI tag canned fixture answers as the live provider.
        assertEquals(ProviderKind.DETERMINISTIC, provider.kind)
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

    @Test
    fun `classify honours a caller token budget on both providers`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"{}"}}]}"""))
        server.enqueue(MockResponse().setBody("""{"content":[{"type":"text","text":"{}"}]}"""))

        OpenAiCompatibleProvider(apiKey = "sk", model = "gpt-4.1", kind = ProviderKind.OPENAI, baseUrl = baseUrl())
            .classify("cues?", maxTokens = 600)
        val openAi = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals(600, openAi["max_tokens"]?.jsonPrimitive?.content?.toInt())

        AnthropicProvider(apiKey = "sk-ant", model = "claude-sonnet-4-5", baseUrl = baseUrl())
            .classify("cues?", maxTokens = 600)
        val anthropic = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals(600, anthropic["max_tokens"]?.jsonPrimitive?.content?.toInt())
    }
}
