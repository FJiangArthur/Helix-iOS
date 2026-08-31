package com.artjiang.helix.ai

import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.TimeUnit

class ModelCatalogTest {

    private lateinit var server: MockWebServer
    private var now = 1_000_000L

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(2, TimeUnit.SECONDS)
        .readTimeout(2, TimeUnit.SECONDS)
        .build()

    private fun baseUrl(): String = server.url("/v1").toString().trimEnd('/')

    private fun catalog(ttlMillis: Long = ModelCatalog.DEFAULT_TTL_MILLIS) = ModelCatalog(
        client = client,
        baseUrlFor = { baseUrl() },
        clock = { now },
        ttlMillis = ttlMillis,
    )

    private fun models(vararg entries: Pair<String, Long?>): String =
        entries.joinToString(",", prefix = """{"data":[""", postfix = "]}") { (id, created) ->
            if (created == null) """{"id":"$id"}""" else """{"id":"$id","created":$created}"""
        }

    // MARK: Requests

    @Test
    fun `openai family issues GET models with bearer auth`() = runTest {
        for (kind in listOf(ProviderKind.OPENAI, ProviderKind.DEEPSEEK, ProviderKind.QWEN, ProviderKind.ZHIPU)) {
            server.enqueue(MockResponse().setBody("""{"data":[]}"""))
            catalog().fetchModels(kind, "  key-$kind ")

            val recorded = server.takeRequest()
            assertEquals("GET", recorded.method)
            assertEquals("/v1/models", recorded.path)
            assertEquals("Bearer key-$kind", recorded.getHeader("Authorization"))
            assertNull(recorded.getHeader("x-api-key"))
        }
    }

    @Test
    fun `anthropic requests the full page with x-api-key and version`() = runTest {
        server.enqueue(MockResponse().setBody("""{"data":[{"id":"claude-sonnet-4-5"}]}"""))
        catalog().fetchModels(ProviderKind.ANTHROPIC, "sk-ant")

        val recorded = server.takeRequest()
        assertEquals("GET", recorded.method)
        assertEquals("/v1/models?limit=1000", recorded.path)
        assertEquals("sk-ant", recorded.getHeader("x-api-key"))
        assertEquals("2023-06-01", recorded.getHeader("anthropic-version"))
        assertNull(recorded.getHeader("Authorization"))
    }

    // MARK: Filtering and ordering

    @Test
    fun `mixed openai body keeps only chat models newest first after fallbacks`() = runTest {
        server.enqueue(
            MockResponse().setBody(
                models(
                    "gpt-4o" to 1_715_367_049L,
                    "text-embedding-3-small" to 1_705_948_997L,
                    "gpt-5" to 1_754_000_000L,
                    "gpt-4o-mini-tts" to 1_742_000_000L,
                    "gpt-realtime" to 1_756_000_000L,
                    "gpt-4o-transcribe" to 1_742_000_001L,
                    "o3-mini" to 1_737_146_383L,
                    "omni-moderation-latest" to 1_731_000_000L,
                    "gpt-image-1" to 1_745_000_000L,
                    "chatgpt-4o-latest" to 1_723_000_000L,
                    "gpt-3.5-turbo-instruct" to 1_692_000_000L,
                    "codex-mini-latest" to 1_746_000_000L,
                    "gpt-4o-search-preview" to 1_741_000_000L,
                ),
            ),
        )

        val options = catalog().listModels(ProviderKind.OPENAI, "sk-test")

        // Live list leads (newest first); curated fallbacks trail as backstop.
        val liveExpected = listOf("gpt-5", "o3-mini", "chatgpt-4o-latest", "gpt-4o")
        assertEquals(liveExpected, options.take(liveExpected.size))
        val fallbacks = ModelCatalog.fallbackModels(ProviderKind.OPENAI)
        assertEquals(
            fallbacks.filterNot { it in liveExpected },
            options.drop(liveExpected.size),
        )
    }

    @Test
    fun `dated openai snapshots collapse into their alias`() {
        val live = listOf(
            DiscoveredModel("gpt-4.1-2025-04-14", 1_744_000_000L),
            DiscoveredModel("gpt-4o-2024-08-06", 1_722_000_000L),
            DiscoveredModel("gpt-4o", 1_715_000_000L),
            // No alias listed → the snapshot stays selectable.
            DiscoveredModel("gpt-4.5-preview-2025-02-27", 1_740_000_000L),
        )
        val options = ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.CHAT)

        assertFalse(options.contains("gpt-4.1-2025-04-14"))
        assertFalse(options.contains("gpt-4o-2024-08-06"))
        assertTrue(options.contains("gpt-4o"))
        assertTrue(options.contains("gpt-4.5-preview-2025-02-27"))
        assertEquals(1, options.count { it == "gpt-4.1" })
    }

    @Test
    fun `transcription role keeps transcribe ids and whisper-1 only`() {
        val live = listOf(
            DiscoveredModel("gpt-4o-mini-transcribe", 1_742_000_000L),
            DiscoveredModel("gpt-live-transcribe", 1_760_000_000L),
            DiscoveredModel("whisper-1", 1_677_000_000L),
            DiscoveredModel("gpt-4.1", 1_744_000_000L),
            DiscoveredModel("gpt-realtime", 1_756_000_000L),
            DiscoveredModel("tts-1", 1_681_000_000L),
        )
        assertEquals(ModelRole.TRANSCRIPTION, ModelCatalog.roleOf("whisper-1", ProviderKind.OPENAI))
        assertEquals(ModelRole.TRANSCRIPTION, ModelCatalog.roleOf("gpt-4o-transcribe", ProviderKind.OPENAI))
        assertNull(ModelCatalog.roleOf("tts-1", ProviderKind.OPENAI))

        val options = ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.TRANSCRIPTION)
        // Live leads newest-first; the fallback backstop appends the one id
        // (gpt-4o-transcribe) the live list happened to miss.
        assertEquals(
            listOf("gpt-live-transcribe", "gpt-4o-mini-transcribe", "whisper-1", "gpt-4o-transcribe"),
            options,
        )
        assertTrue(ModelCatalog.fallbackModels(ProviderKind.ANTHROPIC, ModelRole.TRANSCRIPTION).isEmpty())
    }

    @Test
    fun `realtime role keeps realtime ids only`() {
        val live = listOf(
            DiscoveredModel("gpt-realtime-mini", 1_758_000_000L),
            DiscoveredModel("gpt-4o-realtime-preview", 1_727_000_000L),
            DiscoveredModel("gpt-4.1", 1_744_000_000L),
            DiscoveredModel("gpt-4o-transcribe", 1_742_000_000L),
        )
        assertEquals(ModelRole.REALTIME, ModelCatalog.roleOf("gpt-realtime", ProviderKind.OPENAI))

        val options = ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.REALTIME)
        assertEquals(
            listOf("gpt-realtime-mini", "gpt-4o-realtime-preview") +
                ModelCatalog.fallbackModels(ProviderKind.OPENAI, ModelRole.REALTIME)
                    .filterNot { it in setOf("gpt-realtime-mini", "gpt-4o-realtime-preview") },
            options,
        )
        assertFalse(options.contains("gpt-4.1"))
    }

    @Test
    fun `provider prefixes drop foreign ids`() {
        assertEquals(ModelRole.CHAT, ModelCatalog.roleOf("claude-haiku-4-5", ProviderKind.ANTHROPIC))
        assertNull(ModelCatalog.roleOf("gpt-4.1", ProviderKind.ANTHROPIC))
        assertEquals(ModelRole.CHAT, ModelCatalog.roleOf("deepseek-v4-pro", ProviderKind.DEEPSEEK))
        assertEquals(ModelRole.CHAT, ModelCatalog.roleOf("qwen-plus", ProviderKind.QWEN))
        assertEquals(ModelRole.CHAT, ModelCatalog.roleOf("glm-4", ProviderKind.ZHIPU))
        assertNull(ModelCatalog.roleOf("embedding-3", ProviderKind.ZHIPU))
        assertEquals(ModelRole.CHAT, ModelCatalog.roleOf("o4-mini", ProviderKind.OPENAI))
        assertNull(ModelCatalog.roleOf("gpt-4o-audio-preview", ProviderKind.OPENAI))
        assertNull(ModelCatalog.roleOf("computer-use-preview", ProviderKind.OPENAI))
    }

    @Test
    fun `anthropic created_at iso timestamps order newest first`() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"data":[
                    {"id":"claude-opus-4-1","created_at":"2025-08-05T00:00:00Z"},
                    {"id":"claude-3-5-haiku-20241022","created_at":"2024-10-22T00:00:00+00:00"},
                    {"id":"claude-sonnet-4-20250514","created_at":"2025-05-22T00:00:00Z"},
                    {"id":"claude-undated"}
                ],"has_more":false}""",
            ),
        )

        val options = catalog().listModels(ProviderKind.ANTHROPIC, "sk-ant")

        val liveExpected =
            listOf("claude-opus-4-1", "claude-sonnet-4-20250514", "claude-3-5-haiku-20241022", "claude-undated")
        assertEquals(liveExpected, options.take(liveExpected.size))
        assertEquals(
            ModelCatalog.fallbackModels(ProviderKind.ANTHROPIC).filterNot { it in liveExpected },
            options.drop(liveExpected.size),
        )
    }

    // MARK: Verdicts

    @Test
    fun `401 yields invalid and fetchModels throws the typed http exception`() = runTest {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":{"message":"bad key"}}"""))
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":{"message":"bad key"}}"""))

        val verdict = catalog().checkKey(ProviderKind.OPENAI, "sk-bad")
        assertEquals(KeyCheckResult.Invalid("Invalid API key"), verdict)

        val error = runCatching { catalog().fetchModels(ProviderKind.OPENAI, "sk-bad") }.exceptionOrNull()
        assertTrue(error is ProviderHttpException)
        assertEquals(401, (error as ProviderHttpException).statusCode)
        assertEquals(ProviderKind.OPENAI, error.providerKind)
    }

    @Test
    fun `403 also yields invalid`() = runTest {
        server.enqueue(MockResponse().setResponseCode(403).setBody("forbidden"))
        assertTrue(catalog().checkKey(ProviderKind.ANTHROPIC, "sk-ant") is KeyCheckResult.Invalid)
    }

    @Test
    fun `404 and 405 yield unsupported with the provider name`() = runTest {
        server.enqueue(MockResponse().setResponseCode(404).setBody("not found"))
        server.enqueue(MockResponse().setResponseCode(405).setBody("nope"))

        assertEquals(
            KeyCheckResult.Unsupported("Key saved · model list not available for Zhipu"),
            catalog().checkKey(ProviderKind.ZHIPU, "zp-key"),
        )
        assertEquals(
            KeyCheckResult.Unsupported("Key saved · model list not available for Qwen"),
            catalog().checkKey(ProviderKind.QWEN, "qw-key"),
        )
    }

    @Test
    fun `429 and 5xx yield failed with friendly text`() = runTest {
        server.enqueue(MockResponse().setResponseCode(429).setBody("slow down"))
        server.enqueue(MockResponse().setResponseCode(503).setBody("down"))

        assertEquals(
            KeyCheckResult.Failed("Rate limited by OpenAI, try again"),
            catalog().checkKey(ProviderKind.OPENAI, "sk"),
        )
        assertEquals(
            KeyCheckResult.Failed("DeepSeek error (HTTP 503)"),
            catalog().checkKey(ProviderKind.DEEPSEEK, "ds"),
        )
    }

    @Test
    fun `socket disconnect and server down yield failed network errors`() = runTest {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START))
        val disconnected = catalog().checkKey(ProviderKind.OPENAI, "sk")
        assertTrue(disconnected is KeyCheckResult.Failed)
        assertTrue((disconnected as KeyCheckResult.Failed).message.startsWith("Network error: "))

        val url = baseUrl()
        server.shutdown()
        val down = ModelCatalog(client = client, baseUrlFor = { url }, clock = { now })
            .checkKey(ProviderKind.OPENAI, "sk")
        assertTrue(down is KeyCheckResult.Failed)
        assertTrue((down as KeyCheckResult.Failed).message.startsWith("Network error: "))
    }

    @Test
    fun `malformed bodies yield failed and leave the cache empty`() = runTest {
        server.enqueue(MockResponse().setBody("not json at all"))
        server.enqueue(MockResponse().setBody("""{"object":"list"}"""))
        val catalog = catalog()

        assertEquals(
            KeyCheckResult.Failed("Unexpected response from OpenAI"),
            catalog.checkKey(ProviderKind.OPENAI, "sk"),
        )
        assertEquals(
            KeyCheckResult.Failed("Unexpected response from OpenAI"),
            catalog.checkKey(ProviderKind.OPENAI, "sk"),
        )
        assertNull(catalog.cached(ProviderKind.OPENAI))
    }

    @Test
    fun `blank key is invalid without a request`() = runTest {
        assertTrue(catalog().checkKey(ProviderKind.OPENAI, "   ") is KeyCheckResult.Invalid)
        assertEquals(0, server.requestCount)
    }

    // MARK: Fallbacks and cache

    @Test
    fun `no key lists the curated fallback and never hits the network`() = runTest {
        for (kind in ProviderKind.entries) {
            assertEquals(ModelCatalog.fallbackModels(kind), catalog().listModels(kind, null))
            assertEquals(ModelCatalog.fallbackModels(kind), catalog().listModels(kind, "  "))
        }
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `discovery failure falls back to the curated list`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500).setBody("boom"))
        assertEquals(
            ModelCatalog.fallbackModels(ProviderKind.OPENAI),
            catalog().listModels(ProviderKind.OPENAI, "sk"),
        )
    }

    @Test
    fun `fallback first entry is the domain default for every provider`() {
        for ((name, config) in HelixSettings.defaultProviders()) {
            val kind = ProviderKind.valueOf(name)
            assertEquals(config.smartModel, ModelCatalog.fallbackModels(kind).first())
            assertEquals(config.smartModel, OpenAiCompatibleProvider.defaultModelFor(kind))
        }
        assertEquals(listOf("deepseek-v4-flash", "deepseek-v4-pro"), ModelCatalog.fallbackModels(ProviderKind.DEEPSEEK))
        assertEquals(listOf("gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"), ModelCatalog.fallbackModels(ProviderKind.OPENAI))
        // The keyless kind borrows OpenAI's table.
        assertEquals(ModelCatalog.fallbackModels(ProviderKind.OPENAI), ModelCatalog.fallbackModels(ProviderKind.DETERMINISTIC))
    }

    @Test
    fun `pinned custom id comes first and is not duplicated`() {
        val live = listOf(DiscoveredModel("gpt-4o", 1L), DiscoveredModel("ft:gpt-4.1:acme::abc", 2L))
        val options = ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.CHAT, pinned = " ft:gpt-4.1:acme::abc ")

        assertEquals("ft:gpt-4.1:acme::abc", options.first())
        assertEquals(1, options.count { it == "ft:gpt-4.1:acme::abc" })
        // Live leads after the pin; the fine-tune id is deduped, gpt-4o is the
        // only other live chat id.
        assertEquals("gpt-4o", options[1])

        // A pinned fallback id just keeps its place at the top.
        val pinnedDefault = ModelCatalog.options(null, ProviderKind.OPENAI, ModelRole.CHAT, pinned = "gpt-4.1-mini")
        assertEquals(listOf("gpt-4.1-mini", "gpt-4.1", "gpt-4.1-nano"), pinnedDefault)
    }

    @Test
    fun `cache honours ttl force refresh and invalidate`() = runTest {
        repeat(4) { server.enqueue(MockResponse().setBody(models("gpt-4o" to 1L))) }
        val catalog = catalog(ttlMillis = 1_000)

        catalog.listModels(ProviderKind.OPENAI, "sk")
        catalog.listModels(ProviderKind.OPENAI, "sk")
        assertEquals("fresh cache serves the second call", 1, server.requestCount)
        assertNotNull(catalog.cached(ProviderKind.OPENAI))
        assertEquals(now, catalog.cached(ProviderKind.OPENAI)!!.fetchedAtMillis)

        now += 1_000
        catalog.listModels(ProviderKind.OPENAI, "sk")
        assertEquals("expired cache refetches", 2, server.requestCount)

        catalog.listModels(ProviderKind.OPENAI, "sk", forceRefresh = true)
        assertEquals("force refresh bypasses a fresh cache", 3, server.requestCount)

        catalog.invalidate(ProviderKind.OPENAI)
        assertNull(catalog.cached(ProviderKind.OPENAI))
        catalog.listModels(ProviderKind.OPENAI, "sk")
        assertEquals("invalidate refetches", 4, server.requestCount)
    }

    @Test
    fun `stale cache survives a failed refresh`() = runTest {
        server.enqueue(MockResponse().setBody(models("gpt-4o" to 1L)))
        server.enqueue(MockResponse().setResponseCode(500).setBody("boom"))
        val catalog = catalog(ttlMillis = 1_000)

        catalog.listModels(ProviderKind.OPENAI, "sk")
        now += 5_000
        val options = catalog.listModels(ProviderKind.OPENAI, "sk")

        assertEquals(2, server.requestCount)
        assertTrue(options.contains("gpt-4o"))
    }

    @Test
    fun `cache is keyed per provider`() = runTest {
        server.enqueue(MockResponse().setBody(models("gpt-4o" to 1L)))
        server.enqueue(MockResponse().setBody(models("deepseek-v4-pro" to 1L)))
        val catalog = catalog()

        catalog.listModels(ProviderKind.OPENAI, "sk")
        catalog.listModels(ProviderKind.DEEPSEEK, "ds")
        assertEquals(2, server.requestCount)
        assertEquals("gpt-4o", catalog.cached(ProviderKind.OPENAI)!!.models.single().id)
        assertEquals("deepseek-v4-pro", catalog.cached(ProviderKind.DEEPSEEK)!!.models.single().id)
    }

    @Test
    fun `models url appends the path and the anthropic page size`() {
        assertEquals("https://api.openai.com/v1/models", ModelCatalog.modelsUrl(ProviderKind.OPENAI, "https://api.openai.com/v1/"))
        assertEquals(
            "https://api.anthropic.com/v1/models?limit=1000",
            ModelCatalog.modelsUrl(ProviderKind.ANTHROPIC, ProviderEndpoints.ANTHROPIC),
        )
    }

    // MARK: - Realtime transcription filtering
    //
    // OpenAI ships both `gpt-live-transcribe` (realtime streaming) and
    // `gpt-transcribe` (batch /v1/audio/transcriptions, July 2026). Both
    // contain "transcribe", so the substring rule in roleOf() offered the
    // batch-only model in the realtime picker; selecting it means the socket
    // opens and no delta ever arrives.

    @Test
    fun `batch-only transcription models are not realtime capable`() {
        assertFalse(ModelCatalog.isRealtimeTranscriptionModel("gpt-transcribe"))
        assertFalse(ModelCatalog.isRealtimeTranscriptionModel("gpt-transcribe-mini"))
        assertFalse(ModelCatalog.isRealtimeTranscriptionModel(""))
        assertFalse(ModelCatalog.isRealtimeTranscriptionModel("gpt-4.1"))

        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("gpt-live-transcribe"))
        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("gpt-4o-mini-transcribe"))
        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("gpt-4o-transcribe"))
        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("whisper-1"))
        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("  WHISPER-1 "))
        // A dated snapshot of an allowed alias is accepted by the API.
        assertTrue(ModelCatalog.isRealtimeTranscriptionModel("gpt-4o-transcribe-2025-03-20"))
    }

    @Test
    fun `the transcription picker never offers a batch-only model`() {
        val live = listOf(
            DiscoveredModel("gpt-transcribe", 3_000),
            DiscoveredModel("gpt-live-transcribe", 2_000),
            DiscoveredModel("gpt-4o-transcribe", 1_000),
        )
        val options = ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.TRANSCRIPTION)
        assertFalse("gpt-transcribe" in options)
        assertTrue("gpt-live-transcribe" in options)
        assertTrue("gpt-4o-transcribe" in options)
    }

    @Test
    fun `a pinned batch-only model is not re-offered`() {
        // The pinned id is normally always shown; for realtime transcription
        // that would keep the broken selection alive and selectable.
        val live = listOf(DiscoveredModel("gpt-live-transcribe", 1_000))
        val options = ModelCatalog.options(
            live, ProviderKind.OPENAI, ModelRole.TRANSCRIPTION, pinned = "gpt-transcribe",
        )
        assertFalse("gpt-transcribe" in options)
        assertEquals("gpt-live-transcribe", options.first())

        // A pinned realtime-capable id is still honoured and leads.
        val kept = ModelCatalog.options(
            live, ProviderKind.OPENAI, ModelRole.TRANSCRIPTION, pinned = "whisper-1",
        )
        assertEquals("whisper-1", kept.first())
    }

    @Test
    fun `chat and realtime pickers are unaffected by the transcription filter`() {
        val live = listOf(
            DiscoveredModel("gpt-4.1", 2_000),
            DiscoveredModel("gpt-realtime", 1_000),
        )
        assertTrue("gpt-4.1" in ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.CHAT))
        assertTrue("gpt-realtime" in ModelCatalog.options(live, ProviderKind.OPENAI, ModelRole.REALTIME))
    }

    @Test
    fun `a persisted batch-only model is migrated to the default`() {
        val default = "gpt-live-transcribe"
        assertEquals(default, ModelCatalog.sanitizeRealtimeTranscriptionModel("gpt-transcribe", default))
        assertEquals(default, ModelCatalog.sanitizeRealtimeTranscriptionModel(null, default))
        assertEquals(default, ModelCatalog.sanitizeRealtimeTranscriptionModel("  ", default))
        // A already-valid selection is left exactly as the user set it.
        assertEquals("whisper-1", ModelCatalog.sanitizeRealtimeTranscriptionModel("whisper-1", default))
        assertEquals("whisper-1", ModelCatalog.sanitizeRealtimeTranscriptionModel(" whisper-1 ", default))
    }
}
