package com.artjiang.helix.speech

import com.artjiang.helix.ai.EmptyKeyStore
import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.core.TranscriptSegment
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Base64
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

class OpenAIRealtimeTranscriberTest {

    private lateinit var server: MockWebServer
    private val client = OkHttpClient()
    private val scheduler = ImmediateScheduler()
    private val transcribers = mutableListOf<OpenAIRealtimeTranscriber>()

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        transcribers.forEach { runCatching { it.stop() } }
        scheduler.shutdownNow()
        server.shutdown()
        client.dispatcher.executorService.shutdown()
    }

    /** Delays collapse to "now"; the periodic flush is never installed (tests call flushAudio()). */
    private class ImmediateScheduler : ScheduledThreadPoolExecutor(1) {
        override fun schedule(command: Runnable, delay: Long, unit: TimeUnit): ScheduledFuture<*> =
            super.schedule(command, 0, unit)

        override fun scheduleAtFixedRate(command: Runnable, initialDelay: Long, period: Long, unit: TimeUnit): ScheduledFuture<*> =
            super.schedule({}, 0, unit)
    }

    private class FakeCapture(override val sampleRateHz: Int) : AudioCapture {
        private var onPcm: ((ShortArray, Int) -> Unit)? = null
        @Volatile var started = false
        @Volatile var stopped = false
        var onStart: (() -> Unit)? = null

        override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
            this.onPcm = onPcm
            started = true
            onStart?.invoke()
        }

        override fun stop() {
            stopped = true
        }

        fun feed(samples: Int, amplitude: Int = 1000) {
            onPcm?.invoke(ShortArray(samples) { amplitude.toShort() }, samples)
        }
    }

    private class ServerSide(private val onOpenAction: ((WebSocket) -> Unit)? = null) : WebSocketListener() {
        val messages = LinkedBlockingQueue<String>()
        val closeCodes = LinkedBlockingQueue<Int>()
        val opened = CountDownLatch(1)
        @Volatile var socket: WebSocket? = null

        override fun onOpen(webSocket: WebSocket, response: Response) {
            socket = webSocket
            opened.countDown()
            onOpenAction?.invoke(webSocket)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            messages.add(text)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            closeCodes.add(code)
            webSocket.close(1000, null)
        }

        fun send(text: String) = socket!!.send(text)

        /** Next message, or null after [timeoutMillis]. */
        fun next(timeoutMillis: Long = 3_000): String? = messages.poll(timeoutMillis, TimeUnit.MILLISECONDS)
    }

    private val keyStore = object : KeyStore {
        override fun keyFor(kind: String): String? = if (kind == "OPENAI") "sk-test" else null
    }

    private fun transcriber(
        capture: FakeCapture = FakeCapture(24_000),
        keys: KeyStore = keyStore,
        model: String = "gpt-4o-mini-transcribe",
        clock: () -> Long = System::currentTimeMillis,
    ): OpenAIRealtimeTranscriber = OpenAIRealtimeTranscriber(
        keyStore = keys,
        capture = capture,
        client = client,
        url = server.url("/v1/realtime?intent=transcription").toString(),
        model = { model },
        language = "en",
        sendScheduler = scheduler,
        clock = clock,
        // android.util.Log is not mocked on the JVM; ImmediateScheduler
        // collapses delays to zero, so watchdogs must stay off here (they
        // have their own real-scheduler tests).
        logSink = {},
        connectWatchdogMillis = 0,
        firstDeltaWatchdogMillis = 0,
        gracefulStopTimeoutMillis = 0,
    ).also { transcribers += it }

    private fun await(timeoutMillis: Long = 5_000, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (!condition()) {
            if (System.currentTimeMillis() > deadline) throw AssertionError("condition not met within $timeoutMillis ms")
            Thread.sleep(10)
        }
    }

    private fun openSession(serverSide: ServerSide, capture: FakeCapture = FakeCapture(24_000)): OpenAIRealtimeTranscriber {
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))
        val t = transcriber(capture)
        t.start()
        assertTrue(serverSide.opened.await(3, TimeUnit.SECONDS))
        val first = serverSide.next()
        assertNotNull(first)
        assertTrue(first!!.contains("\"session.update\""))
        return t
    }

    // MARK: - Tests

    @Test
    fun `connects with bearer and beta headers and sends the session update first`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        assertTrue(t.isListening.value)

        val recorded = server.takeRequest()
        assertEquals("/v1/realtime?intent=transcription", recorded.path)
        assertEquals("Bearer sk-test", recorded.getHeader("Authorization"))
        // GA interface: the beta header must NOT be sent.
        assertNull(recorded.getHeader("OpenAI-Beta"))

        // The only message so far was the session update; inspect its model.
        // (openSession consumed it; re-issue start sends nothing new.)
        assertNull(serverSide.next(200))
    }

    @Test
    fun `session update carries the configured model`() {
        val serverSide = ServerSide()
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))
        val t = transcriber(model = "whisper-1")
        t.start()
        val first = serverSide.next()!!
        val root = Json.parseToJsonElement(first).jsonObject
        assertEquals("session.update", root["type"]!!.jsonPrimitive.content)
        val model = root["session"]!!.jsonObject["audio"]!!.jsonObject["input"]!!.jsonObject["transcription"]!!
            .jsonObject["model"]!!.jsonPrimitive.content
        assertEquals("whisper-1", model)
    }

    @Test
    fun `holds audio until the session is ready then appends 24k pcm`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(16_000)
        val t = openSession(serverSide, capture)
        assertTrue(capture.started)

        capture.feed(1_600) // 100 ms at 16 kHz
        t.flushAudio()
        assertNull("no audio before SessionReady", serverSide.next(300))
        assertTrue(t.bufferedBytes > 0)

        serverSide.send("""{"type":"session.created","session":{}}""")
        var append: String? = null
        await {
            t.flushAudio()
            append = serverSide.next(100)
            append != null
        }
        val root = Json.parseToJsonElement(append!!).jsonObject
        assertEquals("input_audio_buffer.append", root["type"]!!.jsonPrimitive.content)
        val bytes = Base64.getDecoder().decode(root["audio"]!!.jsonPrimitive.content)
        // 100 ms resampled to 24 kHz = 2 400 samples = 4 800 bytes (±1 sample at the seam).
        assertTrue("got ${bytes.size}", bytes.size in 4_798..4_802)
        assertEquals(0, bytes.size % 2)
        assertEquals(0, t.bufferedBytes)
    }

    @Test
    fun `delta and completed events map to partial and final segments`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        t.onSegment = { segments += it }

        serverSide.send("""{"type":"session.updated","session":{}}""")
        serverSide.send("""{"type":"conversation.item.input_audio_transcription.delta","item_id":"i1","delta":"Hello"}""")
        serverSide.send("""{"type":"conversation.item.input_audio_transcription.delta","item_id":"i1","delta":" there"}""")
        await { t.partialTranscript.value == "Hello there" }
        assertEquals(2, segments.size)
        assertFalse(segments.last().isFinal)

        serverSide.send("""{"type":"conversation.item.input_audio_transcription.completed","item_id":"i1","transcript":"Hello there."}""")
        await { segments.any { it.isFinal } }
        assertEquals("Hello there.", segments.last().text)
        assertEquals("", t.partialTranscript.value)
        assertTrue(t.isListening.value)
    }

    @Test
    fun `live model commits an audible turn after silence and receives its final before stop`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(24_000)
        val now = AtomicLong(1_700_000_000_000L)
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))
        val t = transcriber(
            capture = capture,
            model = RealtimeEvents.DEFAULT_MODEL,
            clock = { now.get() },
        )
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        t.onSegment = { segments += it }
        t.start()
        assertTrue(serverSide.opened.await(3, TimeUnit.SECONDS))
        assertTrue(serverSide.next()!!.contains("\"session.update\""))
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }

        capture.feed(2_400, amplitude = 0)
        t.flushAudio()
        assertNull("client VAD must not send idle silence before speech", serverSide.next(200))

        capture.feed(4_800, amplitude = 3_000) // 200 ms of audible speech.
        t.flushAudio()
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.delta","item_id":"i-live","delta":"What is the capital of France?"}""",
        )
        await { t.partialTranscript.value.endsWith("France?") }

        now.addAndGet(RealtimeEvents.DEFAULT_SILENCE_DURATION_MS + 1L)
        capture.feed(2_400, amplitude = 0)
        t.flushAudio()

        // The quiet frame is appended first, then the still-open session is
        // committed exactly once so OpenAI can emit TranscriptCompleted.
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        assertEquals(RealtimeEvents.audioCommit(), serverSide.next())
        assertTrue(t.isListening.value)

        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"i-live","transcript":"What is the capital of France?"}""",
        )
        await { segments.any { it.isFinal } }
        assertEquals("What is the capital of France?", segments.last().text)
        assertTrue("completion must arrive before the user stops the session", t.isListening.value)

        now.addAndGet(RealtimeEvents.DEFAULT_SILENCE_DURATION_MS + 1L)
        capture.feed(2_400, amplitude = 0)
        t.flushAudio()
        assertNull("continued idle silence must not grow the next server buffer", serverSide.next(200))

        capture.feed(4_800, amplitude = 3_000)
        t.flushAudio()
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.delta","item_id":"i-live-2","delta":"And Germany?"}""",
        )
        now.addAndGet(RealtimeEvents.DEFAULT_SILENCE_DURATION_MS + 1L)
        capture.feed(2_400, amplitude = 0)
        t.flushAudio()
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        assertEquals(RealtimeEvents.audioCommit(), serverSide.next())
        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"i-live-2","transcript":"And Germany?"}""",
        )
        await { segments.count { it.isFinal } == 2 }
        assertEquals(listOf("What is the capital of France?", "And Germany?"), segments.filter { it.isFinal }.map { it.text })
    }

    @Test
    fun `in-band auth error stops listening with a 401 message and no retry`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(24_000)
        val t = openSession(serverSide, capture)

        serverSide.send("""{"type":"error","error":{"type":"invalid_request_error","code":"invalid_api_key","message":"Incorrect API key provided"}}""")
        await { !t.isListening.value }
        assertTrue(t.errorMessage.value, t.errorMessage.value.contains("401"))
        assertTrue(t.errorMessage.value.contains("OpenAI"))
        assertTrue(capture.stopped)
        Thread.sleep(300)
        assertEquals(1, server.requestCount)
    }

    @Test
    fun `upgrade 401 fails without retry`() {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":"unauthorized"}"""))
        val capture = FakeCapture(24_000)
        val t = transcriber(capture)
        t.start()
        await { !t.isListening.value && t.errorMessage.value.isNotEmpty() }
        assertTrue(t.errorMessage.value, t.errorMessage.value.contains("401"))
        assertTrue(capture.stopped)
        Thread.sleep(300)
        assertEquals(1, server.requestCount)
    }

    @Test
    fun `server close reconnects twice then fails`() {
        repeat(3) {
            server.enqueue(MockResponse().withWebSocketUpgrade(ServerSide { ws -> ws.close(1011, "session expired") }))
        }
        val t = transcriber()
        t.start()
        await(8_000) { !t.isListening.value && t.errorMessage.value.isNotEmpty() }
        assertTrue(t.errorMessage.value, t.errorMessage.value.contains("stopped"))
        Thread.sleep(300)
        assertEquals(1 + OpenAIRealtimeTranscriber.MAX_RETRIES, server.requestCount)
    }

    @Test
    fun `stop commits buffered audio waits for the final then closes with 1000`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(24_000)
        val t = openSession(serverSide, capture)
        serverSide.send("""{"type":"session.created","session":{}}""")

        capture.feed(4_800) // 200 ms ≥ the 100 ms commit floor
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        t.onSegment = { segments += it }
        var append: String? = null
        await {
            t.flushAudio()
            append = serverSide.next(100)
            append != null
        }
        t.stop()

        assertFalse(t.isListening.value)
        assertTrue(capture.stopped)
        val commit = serverSide.next()
        assertEquals(RealtimeEvents.audioCommit(), commit)
        assertNull("socket must stay eligible for the final", serverSide.closeCodes.poll(200, TimeUnit.MILLISECONDS))
        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"stop-tail","transcript":"Last words."}""",
        )
        await { segments.any { it.isFinal } }
        assertEquals("Last words.", segments.last().text)
        assertEquals(1000, serverSide.closeCodes.poll(3, TimeUnit.SECONDS))
    }

    @Test
    fun `stop after an auto committed final closes without a duplicate commit or final`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(24_000)
        val now = AtomicLong(1_700_000_000_000L)
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))
        val t = transcriber(capture = capture, model = RealtimeEvents.DEFAULT_MODEL, clock = { now.get() })
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        t.onSegment = { segments += it }
        t.start()
        assertTrue(serverSide.opened.await(3, TimeUnit.SECONDS))
        assertTrue(serverSide.next()!!.contains("session.update"))
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }

        capture.feed(4_800, amplitude = 3_000)
        t.flushAudio()
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        now.addAndGet(RealtimeEvents.DEFAULT_SILENCE_DURATION_MS + 1L)
        capture.feed(2_400, amplitude = 0)
        t.flushAudio()
        assertTrue(serverSide.next()!!.contains("input_audio_buffer.append"))
        assertEquals(RealtimeEvents.audioCommit(), serverSide.next())
        serverSide.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"done","transcript":"Already final."}""",
        )
        await { segments.count { it.isFinal } == 1 }

        t.stop()

        assertNull("completed audio must not be committed twice", serverSide.next(200))
        assertEquals(1000, serverSide.closeCodes.poll(3, TimeUnit.SECONDS))
        assertEquals(1, segments.count { it.isFinal })
    }

    @Test
    fun `stop without enough audio skips the commit`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        serverSide.send("""{"type":"session.created","session":{}}""")
        Thread.sleep(100)

        t.stop()
        assertEquals(1000, serverSide.closeCodes.poll(3, TimeUnit.SECONDS))
        assertNull(serverSide.next(200))
        assertFalse(t.isListening.value)
    }

    @Test
    fun `missing key errors without touching the network`() {
        val capture = FakeCapture(24_000)
        val t = transcriber(capture, keys = EmptyKeyStore)
        t.start()
        assertFalse(t.isListening.value)
        assertEquals(OpenAIRealtimeTranscriber.MISSING_KEY_MESSAGE, t.errorMessage.value)
        assertFalse(capture.started)
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `outbox keeps only the last five seconds`() {
        val serverSide = ServerSide()
        val capture = FakeCapture(24_000)
        val t = openSession(serverSide, capture)
        // Session never becomes ready, so nothing drains.
        repeat(60) { capture.feed(2_400) } // 6 s in 100 ms chunks
        assertEquals(OpenAIRealtimeTranscriber.OUTBOX_CAPACITY_BYTES, t.bufferedBytes)
        assertEquals(48_000L, t.droppedBytes)
    }

    // MARK: - Stop / restart lifecycle
    //
    // A reconnect scheduled by reconnectOrFail used to be untracked: neither
    // stop() nor fail() cancelled it. Stopping during the 1-2 s backoff left it
    // pending, and it then fired into the NEXT session (which had already set
    // isListening back to true), opening a second socket that raced the real
    // one on socketGeneration. The restart looked live but produced nothing.

    /** Real delays, so a pending reconnect survives a stop() the way it does on device. */
    private class DelayingScheduler : ScheduledThreadPoolExecutor(2)

    private fun transcriberOn(
        realScheduler: java.util.concurrent.ScheduledExecutorService,
        capture: FakeCapture = FakeCapture(24_000),
    ): OpenAIRealtimeTranscriber = OpenAIRealtimeTranscriber(
        keyStore = keyStore,
        capture = capture,
        client = client,
        url = server.url("/v1/realtime?intent=transcription").toString(),
        model = { "gpt-4o-mini-transcribe" },
        language = "en",
        sendScheduler = realScheduler,
        logSink = {},
        connectWatchdogMillis = 0,
        firstDeltaWatchdogMillis = 0,
    ).also { transcribers += it }

    @Test
    fun `rapid restart closes the graceful-stop socket and rejects its late final`() {
        val oldServer = ServerSide()
        val newServer = ServerSide()
        val capture = FakeCapture(24_000)
        val starts = AtomicInteger()
        val restartCaptureEntered = CountDownLatch(1)
        val allowRestartToConnect = CountDownLatch(1)
        capture.onStart = {
            if (starts.incrementAndGet() == 2) {
                restartCaptureEntered.countDown()
                allowRestartToConnect.await(5, TimeUnit.SECONDS)
            }
        }
        server.enqueue(MockResponse().withWebSocketUpgrade(oldServer))
        val t = transcriber(capture = capture)
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        t.onSegment = { segments += it }
        t.start()
        assertTrue(oldServer.opened.await(3, TimeUnit.SECONDS))
        assertTrue(oldServer.next()!!.contains("session.update"))
        oldServer.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        capture.feed(4_800, amplitude = 3_000)
        t.flushAudio()
        assertTrue(oldServer.next()!!.contains("input_audio_buffer.append"))

        t.stop()
        assertEquals(RealtimeEvents.audioCommit(), oldServer.next())
        server.enqueue(MockResponse().withWebSocketUpgrade(newServer))
        val restart = Thread({ t.start() }, "rapid-restart-test")
        restart.start()
        try {
            assertTrue(restartCaptureEntered.await(3, TimeUnit.SECONDS))
            oldServer.send(
                """{"type":"conversation.item.input_audio_transcription.completed","item_id":"old-tail","transcript":"Old session tail."}""",
            )
            Thread.sleep(200)
            assertFalse(
                "the stopped socket's late final crossed into the restarted source",
                segments.any { it.text == "Old session tail." },
            )
            assertEquals(
                "restart must close the old graceful-stop socket instead of orphaning it",
                1000,
                oldServer.closeCodes.poll(3, TimeUnit.SECONDS),
            )
        } finally {
            allowRestartToConnect.countDown()
            restart.join(5_000)
        }

        assertTrue("the restarted source never connected", newServer.opened.await(3, TimeUnit.SECONDS))
        assertTrue(newServer.next()!!.contains("session.update"))
        newServer.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        newServer.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"new-final","transcript":"New session final."}""",
        )
        await { segments.any { it.text == "New session final." } }
        assertEquals(listOf("New session final."), segments.filter { it.isFinal }.map { it.text })
    }

    @Test
    fun `restart rejects an old final already inside its socket callback`() {
        val oldServer = ServerSide()
        val newServer = ServerSide()
        val capture = FakeCapture(24_000)
        server.enqueue(MockResponse().withWebSocketUpgrade(oldServer))
        val t = transcriber(capture = capture)
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        val oldFrameEntered = CountDownLatch(1)
        val allowOldFrameToParse = CountDownLatch(1)
        t.onSegment = { segments += it }
        t.onRawFrame = { frame ->
            if (frame.contains("old-in-flight")) {
                oldFrameEntered.countDown()
                allowOldFrameToParse.await(5, TimeUnit.SECONDS)
            }
        }
        t.start()
        assertTrue(oldServer.opened.await(3, TimeUnit.SECONDS))
        assertTrue(oldServer.next()!!.contains("session.update"))
        oldServer.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        capture.feed(4_800, amplitude = 3_000)
        t.flushAudio()
        assertTrue(oldServer.next()!!.contains("input_audio_buffer.append"))
        t.stop()
        assertEquals(RealtimeEvents.audioCommit(), oldServer.next())

        oldServer.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"old-in-flight","transcript":"Old in-flight final."}""",
        )
        assertTrue(oldFrameEntered.await(3, TimeUnit.SECONDS))
        server.enqueue(MockResponse().withWebSocketUpgrade(newServer))
        t.start()
        allowOldFrameToParse.countDown()

        assertTrue(newServer.opened.await(3, TimeUnit.SECONDS))
        assertTrue(newServer.next()!!.contains("session.update"))
        newServer.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        newServer.send(
            """{"type":"conversation.item.input_audio_transcription.completed","item_id":"new-after-race","transcript":"New final after restart."}""",
        )
        await { segments.any { it.text == "New final after restart." } }

        assertEquals(listOf("New final after restart."), segments.filter { it.isFinal }.map { it.text })
    }

    @Test
    fun `stopping during backoff cancels the pending reconnect`() {
        val delaying = DelayingScheduler()
        try {
            // First socket is accepted then closed by the server: that schedules
            // a reconnect ~1 s out.
            server.enqueue(MockResponse().withWebSocketUpgrade(ServerSide { ws -> ws.close(1011, "expired") }))
            val t = transcriberOn(delaying)
            t.start()
            await(5_000) { server.requestCount == 1 }

            // Stop well inside the backoff window.
            t.stop()
            assertFalse(t.isListening.value)

            // The cancelled reconnect must never reach the network.
            Thread.sleep(2_500)
            assertEquals(1, server.requestCount)
        } finally {
            delaying.shutdownNow()
        }
    }

    @Test
    fun `restarting during backoff opens exactly one socket for the new session`() {
        val delaying = DelayingScheduler()
        try {
            server.enqueue(MockResponse().withWebSocketUpgrade(ServerSide { ws -> ws.close(1011, "expired") }))
            val t = transcriberOn(delaying)
            t.start()
            await(5_000) { server.requestCount == 1 }

            // Stop + restart inside the backoff window — the user ending a
            // stuck session and starting a new one.
            t.stop()
            val fresh = ServerSide()
            server.enqueue(MockResponse().withWebSocketUpgrade(fresh))
            t.start()

            assertTrue("restarted session never connected", fresh.opened.await(5, TimeUnit.SECONDS))
            assertTrue(t.isListening.value)
            val first = fresh.next()
            assertNotNull(first)
            assertTrue(first!!.contains("\"session.update\""))

            // Exactly two connects total: the original and the restart. A stale
            // reconnect firing into the new session would make it three.
            Thread.sleep(2_500)
            assertEquals(2, server.requestCount)
            assertTrue(t.isListening.value)
        } finally {
            delaying.shutdownNow()
        }
    }

    @Test
    fun `the first-delta watchdog message names a batch-only model`() {
        val batch = OpenAIRealtimeTranscriber.deltaWatchdogMessage("gpt-transcribe")
        assertTrue(batch, batch.contains("gpt-transcribe"))
        assertTrue(batch, batch.contains("not a realtime transcription model"))
        // It must tell the user what to pick instead.
        assertTrue(batch, batch.contains("gpt-live-transcribe"))
        assertTrue(batch, batch.contains("whisper-1"))

        // A valid model keeps the generic message: the model is not the cause.
        assertEquals(
            OpenAIRealtimeTranscriber.DELTA_WATCHDOG_MESSAGE,
            OpenAIRealtimeTranscriber.deltaWatchdogMessage("gpt-live-transcribe"),
        )
        assertEquals(
            OpenAIRealtimeTranscriber.DELTA_WATCHDOG_MESSAGE,
            OpenAIRealtimeTranscriber.deltaWatchdogMessage(""),
        )
    }
}
