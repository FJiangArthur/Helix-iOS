package com.artjiang.helix.ai

import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList

/**
 * SSE streaming for both provider dialects.
 *
 * MockWebServer serves the event-stream body as a plain chunked body — the
 * parser only cares about lines, so this exercises the real decoder, the real
 * OkHttp call, and the real delta extraction.
 */
class ProviderStreamingTest {

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

    private fun request(question: String = "What is RAG?") = AnswerRequest(
        question = question,
        mode = ConversationMode.ACTIVE,
        skill = ActiveSkill(),
        maxResponseSentences = 3,
    )

    private fun sseResponse(body: String) = MockResponse()
        .setHeader("Content-Type", "text/event-stream")
        .setBody(body)

    private fun openAiChunk(content: String, model: String = "gpt-4.1"): String =
        """data: {"model":"$model","choices":[{"delta":{"content":${quote(content)}}}]}"""

    private fun quote(raw: String): String = "\"" + raw.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

    // MARK: - Pure SSE line decoding

    @Test
    fun `sse decoder frames events on blank lines and strips one leading space`() {
        val decoder = SseLineDecoder()
        assertEquals(null, decoder.accept("data: one"))
        assertEquals(SseEvent("one"), decoder.accept(""))
        // No space after the colon is equally legal.
        assertEquals(null, decoder.accept("data:two"))
        assertEquals(SseEvent("two"), decoder.accept(""))
    }

    @Test
    fun `sse decoder ignores comments and non-data fields`() {
        val decoder = SseLineDecoder()
        assertEquals(null, decoder.accept(": keep-alive"))
        assertEquals(null, decoder.accept("event: content_block_delta"))
        assertEquals(null, decoder.accept("id: 42"))
        assertEquals(null, decoder.accept("data: payload"))
        assertEquals(SseEvent("payload"), decoder.accept(""))
    }

    @Test
    fun `sse decoder joins multiple data lines in one frame with newlines`() {
        val decoder = SseLineDecoder()
        decoder.accept("data: first")
        decoder.accept("data: second")
        assertEquals(SseEvent("first\nsecond"), decoder.accept(""))
    }

    @Test
    fun `sse decoder flush emits a frame the body never terminated`() {
        val decoder = SseLineDecoder()
        decoder.accept("data: trailing")
        assertEquals(SseEvent("trailing"), decoder.flush())
        // Nothing pending afterwards.
        assertEquals(null, decoder.flush())
    }

    // MARK: - OpenAI dialect

    @Test
    fun `openai stream surfaces deltas in order and returns the joined answer`() = runTest {
        server.enqueue(
            sseResponse(
                buildString {
                    appendLine(openAiChunk("RAG "))
                    appendLine()
                    appendLine(openAiChunk("grounds "))
                    appendLine()
                    appendLine(openAiChunk("answers."))
                    appendLine()
                    appendLine("data: $SSE_DONE")
                    appendLine()
                },
            ),
        )

        val deltas = mutableListOf<String>()
        val provider = OpenAiCompatibleProvider(
            apiKey = "sk-test",
            model = "gpt-4.1",
            kind = ProviderKind.OPENAI,
            baseUrl = baseUrl(),
        )
        val response = provider.answer(request()) { deltas += it }

        assertEquals(listOf("RAG ", "grounds ", "answers."), deltas)
        assertEquals("RAG grounds answers.", response.text)
        assertEquals(ProviderKind.OPENAI, response.providerKind)
        assertEquals("gpt-4.1", response.model)

        val recorded = server.takeRequest()
        assertEquals("/v1/chat/completions", recorded.path)
        val body = helixJson.parseToJsonElement(recorded.body.readUtf8()).jsonObject
        assertEquals(true, body["stream"]?.jsonPrimitive?.content?.toBoolean())
    }

    @Test
    fun `openai non streaming call omits the stream flag`() = runTest {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))
        val provider = OpenAiCompatibleProvider(
            apiKey = "sk-test",
            model = "gpt-4.1",
            kind = ProviderKind.OPENAI,
            baseUrl = baseUrl(),
        )
        assertEquals("ok", provider.answer(request()).text)

        val body = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals(null, body["stream"])
    }

    @Test
    fun `openai stream tolerates keep alives and empty deltas`() = runTest {
        server.enqueue(
            sseResponse(
                buildString {
                    appendLine(": ping")
                    appendLine()
                    // Role-only opening chunk carries no content.
                    appendLine("""data: {"choices":[{"delta":{"role":"assistant"}}]}""")
                    appendLine()
                    appendLine("data: not-json-at-all")
                    appendLine()
                    appendLine(openAiChunk("Hello."))
                    appendLine()
                    appendLine("data: $SSE_DONE")
                    appendLine()
                },
            ),
        )

        val deltas = mutableListOf<String>()
        val provider = OpenAiCompatibleProvider(
            apiKey = "sk-test",
            model = "gpt-4.1",
            baseUrl = baseUrl(),
        )
        val response = provider.answer(request()) { deltas += it }

        assertEquals(listOf("Hello."), deltas)
        assertEquals("Hello.", response.text)
    }

    @Test
    fun `openai stream with no text throws empty response`() = runTest {
        server.enqueue(sseResponse("data: $SSE_DONE\n\n"))
        val provider = OpenAiCompatibleProvider(apiKey = "sk-test", model = "gpt-4.1", baseUrl = baseUrl())

        val error = runCatching { provider.answer(request()) {} }.exceptionOrNull()
        assertTrue("expected empty-response, got $error", error is ProviderEmptyResponseException)
    }

    @Test
    fun `openai stream maps a non 2xx to the same http exception as the buffered path`() = runTest {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":{"message":"bad key"}}"""))
        val provider = OpenAiCompatibleProvider(apiKey = "sk-bad", model = "gpt-4.1", baseUrl = baseUrl())

        val deltas = mutableListOf<String>()
        val error = runCatching { provider.answer(request()) { deltas += it } }.exceptionOrNull()

        assertTrue("expected http error, got $error", error is ProviderHttpException)
        assertEquals(401, (error as ProviderHttpException).statusCode)
        assertTrue(error.bodySnippet.contains("bad key"))
        assertTrue("no deltas on a failed call", deltas.isEmpty())
    }

    @Test
    fun `openai stream truncated mid answer surfaces the deltas it did receive`() = runTest {
        // Body ends after two chunks with no [DONE] — a dropped connection.
        server.enqueue(
            sseResponse(
                buildString {
                    appendLine(openAiChunk("Partial "))
                    appendLine()
                    appendLine(openAiChunk("answer"))
                    appendLine()
                },
            ),
        )

        val deltas = mutableListOf<String>()
        val provider = OpenAiCompatibleProvider(apiKey = "sk-test", model = "gpt-4.1", baseUrl = baseUrl())
        val response = provider.answer(request()) { deltas += it }

        assertEquals(listOf("Partial ", "answer"), deltas)
        assertEquals("Partial answer", response.text)
    }

    // MARK: - Anthropic dialect

    @Test
    fun `anthropic stream surfaces content block deltas in order`() = runTest {
        server.enqueue(
            sseResponse(
                buildString {
                    appendLine("event: message_start")
                    appendLine("""data: {"type":"message_start","message":{"model":"claude-sonnet-4"}}""")
                    appendLine()
                    appendLine("event: ping")
                    appendLine("""data: {"type":"ping"}""")
                    appendLine()
                    appendLine("event: content_block_delta")
                    appendLine("""data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Retrieval "}}""")
                    appendLine()
                    appendLine("event: content_block_delta")
                    appendLine("""data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"grounds it."}}""")
                    appendLine()
                    appendLine("event: message_stop")
                    appendLine("""data: {"type":"message_stop"}""")
                    appendLine()
                },
            ),
        )

        val deltas = mutableListOf<String>()
        val provider = AnthropicProvider(apiKey = "ak-test", model = "claude-haiku-4", baseUrl = baseUrl())
        val response = provider.answer(request()) { deltas += it }

        assertEquals(listOf("Retrieval ", "grounds it."), deltas)
        assertEquals("Retrieval grounds it.", response.text)
        assertEquals(ProviderKind.ANTHROPIC, response.providerKind)
        // message_start's model wins over the configured one, matching the
        // buffered path's "prefer what the API reports".
        assertEquals("claude-sonnet-4", response.model)

        val recorded = server.takeRequest()
        assertEquals("/v1/messages", recorded.path)
        assertEquals("ak-test", recorded.getHeader("x-api-key"))
        val body = helixJson.parseToJsonElement(recorded.body.readUtf8()).jsonObject
        assertEquals(true, body["stream"]?.jsonPrimitive?.content?.toBoolean())
    }

    @Test
    fun `anthropic stream stops at message stop and ignores anything after it`() = runTest {
        server.enqueue(
            sseResponse(
                buildString {
                    appendLine("""data: {"type":"content_block_delta","delta":{"text":"kept"}}""")
                    appendLine()
                    appendLine("""data: {"type":"message_stop"}""")
                    appendLine()
                    appendLine("""data: {"type":"content_block_delta","delta":{"text":" dropped"}}""")
                    appendLine()
                },
            ),
        )

        val deltas = mutableListOf<String>()
        val provider = AnthropicProvider(apiKey = "ak-test", model = "claude-haiku-4", baseUrl = baseUrl())
        val response = provider.answer(request()) { deltas += it }

        assertEquals(listOf("kept"), deltas)
        assertEquals("kept", response.text)
    }

    @Test
    fun `anthropic non streaming call omits the stream flag`() = runTest {
        server.enqueue(MockResponse().setBody("""{"content":[{"type":"text","text":"ok"}]}"""))
        val provider = AnthropicProvider(apiKey = "ak-test", model = "claude-haiku-4", baseUrl = baseUrl())
        assertEquals("ok", provider.answer(request()).text)

        val body = helixJson.parseToJsonElement(server.takeRequest().body.readUtf8()).jsonObject
        assertEquals(null, body["stream"])
    }

    // MARK: - Cancellation

    @Test
    fun `cancelling mid stream stops delivering deltas`() = runTest {
        // A genuinely open stream: the body is delivered in throttled slices so
        // the first chunk arrives promptly while the provider is then parked in
        // a socket read waiting for the rest — the real state a user cancel has
        // to interrupt. Without the isActive check in streamSse, the trailing
        // "second" deltas would still be delivered after the cancel.
        val head = openAiChunk("first") + "\n\n"
        val trailing = buildString {
            repeat(32) {
                appendLine(openAiChunk("second"))
                appendLine()
            }
        }
        server.enqueue(
            sseResponse(head + trailing)
                // One head-sized slice per 500 ms: chunk one lands immediately,
                // the remainder trickles in well past the cancel below.
                .throttleBody(head.length.toLong(), 500, java.util.concurrent.TimeUnit.MILLISECONDS),
        )

        val deltas = CopyOnWriteArrayList<String>()
        val sawFirst = CompletableDeferred<Unit>()
        val provider = OpenAiCompatibleProvider(apiKey = "sk-test", model = "gpt-4.1", baseUrl = baseUrl())

        // Real dispatchers: the provider blocks in a socket read, which the
        // test scheduler's virtual time cannot advance past.
        withContext(Dispatchers.IO) {
            val job = launch {
                runCatching {
                    provider.answer(request()) {
                        deltas += it
                        sawFirst.complete(Unit)
                    }
                }
            }
            withTimeout(10_000) { sawFirst.await() }
            job.cancel()
            job.join()
        }

        // Cancel landed while the rest of the stream was still arriving.
        assertEquals(listOf("first"), deltas.toList())
        assertFalse("stream kept delivering after cancel", deltas.size > 1)
    }

    // MARK: - Deterministic provider

    @Test
    fun `deterministic provider emits its whole answer as one delta`() = runTest {
        val deltas = mutableListOf<String>()
        val response = DeterministicProvider().answer(request()) { deltas += it }

        assertEquals(1, deltas.size)
        assertEquals(response.text, deltas.single())
    }

    @Test
    fun `deterministic provider still works without a delta sink`() = runTest {
        assertTrue(DeterministicProvider().answer(request()).text.isNotEmpty())
    }
}
