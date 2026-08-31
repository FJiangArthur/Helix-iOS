package com.artjiang.helix.speech

import com.artjiang.helix.ai.KeyStore
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * Diagnostics-hardening coverage: the bounded diagnostics trail, logSink,
 * watchdogs (real scheduler, short timeouts), post-config error surfacing,
 * RMS input level, speech-energy latch, and the "no audio" hysteresis.
 */
class OpenAIRealtimeTranscriberDiagnosticsTest {

    private lateinit var server: MockWebServer
    private val client = OkHttpClient()
    private val scheduler = ScheduledThreadPoolExecutor(1)
    private val transcribers = mutableListOf<OpenAIRealtimeTranscriber>()
    private val logLines = CopyOnWriteArrayList<String>()

    /** Mutable clock so hysteresis windows are deterministic. */
    private val nowMillis = AtomicLong(1_700_000_000_000L)

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

    private class FakeCapture(override val sampleRateHz: Int = 24_000) : AudioCapture {
        private var onPcm: ((ShortArray, Int) -> Unit)? = null
        @Volatile var stopped = false

        override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
            this.onPcm = onPcm
        }

        override fun stop() {
            stopped = true
        }

        fun feed(samples: Int, amplitude: Int) {
            onPcm?.invoke(ShortArray(samples) { amplitude.toShort() }, samples)
        }
    }

    private class ServerSide : WebSocketListener() {
        val messages = LinkedBlockingQueue<String>()
        val opened = CountDownLatch(1)
        @Volatile var socket: WebSocket? = null

        override fun onOpen(webSocket: WebSocket, response: Response) {
            socket = webSocket
            opened.countDown()
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            messages.add(text)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(1000, null)
        }

        fun send(text: String) = socket!!.send(text)
    }

    private val keyStore = object : KeyStore {
        override fun keyFor(kind: String): String? = if (kind == "OPENAI") "sk-test" else null
    }

    private fun transcriber(
        capture: FakeCapture = FakeCapture(),
        connectWatchdogMillis: Long = 0,
        firstDeltaWatchdogMillis: Long = 0,
    ): OpenAIRealtimeTranscriber = OpenAIRealtimeTranscriber(
        keyStore = keyStore,
        capture = capture,
        client = client,
        url = server.url("/v1/realtime?intent=transcription").toString(),
        model = { "gpt-4o-mini-transcribe" },
        language = "en",
        sendScheduler = scheduler,
        clock = { nowMillis.get() },
        logSink = { logLines += it },
        connectWatchdogMillis = connectWatchdogMillis,
        firstDeltaWatchdogMillis = firstDeltaWatchdogMillis,
    ).also { transcribers += it }

    private fun await(timeoutMillis: Long = 5_000, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (!condition()) {
            if (System.currentTimeMillis() > deadline) throw AssertionError("condition not met within $timeoutMillis ms")
            Thread.sleep(10)
        }
    }

    private fun openSession(
        serverSide: ServerSide,
        capture: FakeCapture = FakeCapture(),
        connectWatchdogMillis: Long = 0,
        firstDeltaWatchdogMillis: Long = 0,
    ): OpenAIRealtimeTranscriber {
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))
        val t = transcriber(capture, connectWatchdogMillis, firstDeltaWatchdogMillis)
        t.start()
        assertTrue(serverSide.opened.await(3, TimeUnit.SECONDS))
        assertNotNull(serverSide.messages.poll(3, TimeUnit.SECONDS)) // session.update
        return t
    }

    private fun diagText(t: OpenAIRealtimeTranscriber): String = t.diagnostics.value.joinToString("\n")

    // MARK: - Diagnostics trail

    @Test
    fun `unknown events are recorded in diagnostics and the log sink`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        serverSide.send("""{"type":"rate_limits.updated","rate_limits":[]}""")
        serverSide.send("""{"type":"input_audio_buffer.speech_started"}""")
        await { diagText(t).contains("unknown event: input_audio_buffer.speech_started") }
        assertTrue(diagText(t).contains("unknown event: rate_limits.updated"))
        assertTrue(logLines.any { it.contains("unknown event: rate_limits.updated") })
        assertTrue(t.isListening.value)
    }

    @Test
    fun `post-config server error surfaces via errorMessage without killing the session`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        serverSide.send("""{"type":"error","error":{"type":"invalid_request_error","code":"model_not_found","message":"The model does not exist"}}""")
        await { t.errorMessage.value.isNotEmpty() }
        assertTrue(t.errorMessage.value, t.errorMessage.value.contains("The model does not exist"))
        assertTrue(diagText(t).contains("server error (post-config)"))
        assertTrue("session should survive an in-session error", t.isListening.value)
    }

    @Test
    fun `session lifecycle is recorded connected configured first delta`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        serverSide.send("""{"type":"session.created","session":{}}""")
        serverSide.send("""{"type":"conversation.item.input_audio_transcription.delta","item_id":"i1","delta":"Hi"}""")
        await { t.hasFirstDelta }
        val text = diagText(t)
        assertTrue(text, text.contains("session start"))
        assertTrue(text, text.contains("socket connected"))
        assertTrue(text, text.contains("session configured"))
        assertTrue(text, text.contains("first transcript delta"))
        // Every line is timestamped HH:MM:SS.mmm.
        t.diagnostics.value.forEach { line ->
            assertTrue(line, Regex("^\\d{2}:\\d{2}:\\d{2}\\.\\d{3} ").containsMatchIn(line))
        }
    }

    @Test
    fun `diagnostics trail is bounded to the last fifty lines`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        repeat(120) { serverSide.send("""{"type":"unknown.event.$it"}""") }
        await { diagText(t).contains("unknown.event.119") }
        assertTrue(t.diagnostics.value.size <= OpenAIRealtimeTranscriber.DIAG_MAX_LINES)
        assertTrue("oldest lines must be evicted", t.diagnostics.value.none { it.endsWith("unknown.event.5") })
    }

    @Test
    fun `outbox overflow is recorded once per session`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture)
        // Session never becomes ready; 6+ s of audio overflows the 5 s ring.
        repeat(70) { capture.feed(2_400, amplitude = 1000) }
        assertTrue(t.droppedBytes > 0)
        assertEquals(1, t.diagnostics.value.count { it.contains("outbox overflow") })
    }

    // MARK: - Watchdogs

    @Test
    fun `connect watchdog fails when SessionReady never arrives`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture, connectWatchdogMillis = 250)
        await { !t.isListening.value }
        assertEquals(OpenAIRealtimeTranscriber.CONNECT_WATCHDOG_MESSAGE, t.errorMessage.value)
        assertTrue(capture.stopped)
        assertTrue(diagText(t).contains("watchdog: no SessionReady"))
    }

    @Test
    fun `connect watchdog does not fire once the session is ready`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide, connectWatchdogMillis = 250)
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        Thread.sleep(500)
        assertTrue(t.isListening.value)
        assertEquals("", t.errorMessage.value)
    }

    @Test
    fun `first-delta watchdog fires only after speech energy with no transcript`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture, firstDeltaWatchdogMillis = 250)
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }

        // Silence only: the watchdog must keep rescheduling, never fail.
        capture.feed(2_400, amplitude = 0)
        Thread.sleep(600)
        assertTrue("silence alone must not trip the watchdog", t.isListening.value)

        // Speech-level energy with no transcript: now it must fire. The
        // injected clock is manual, so advance it past the watchdog window.
        capture.feed(2_400, amplitude = 3_000)
        assertTrue(t.speechEnergySeen)
        nowMillis.addAndGet(1_000)
        await(3_000) { !t.isListening.value }
        assertEquals(OpenAIRealtimeTranscriber.DELTA_WATCHDOG_MESSAGE, t.errorMessage.value)
        assertTrue(diagText(t).contains("watchdog: speech energy but no transcript"))
    }

    @Test
    fun `first-delta watchdog stays quiet when transcripts flow`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture, firstDeltaWatchdogMillis = 250)
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        capture.feed(2_400, amplitude = 3_000)
        serverSide.send("""{"type":"conversation.item.input_audio_transcription.delta","item_id":"i1","delta":"Hello"}""")
        await { t.hasFirstDelta }
        Thread.sleep(600)
        assertTrue(t.isListening.value)
        assertEquals("", t.errorMessage.value)
    }

    // MARK: - RMS / no-audio detection

    @Test
    fun `input level tracks frame rms and speech energy latches`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture)
        assertEquals(0f, t.inputLevel.value, 0.0001f)
        assertFalse(t.speechEnergySeen)

        capture.feed(2_400, amplitude = 3_277) // rms ≈ 0.1
        assertTrue(t.inputLevel.value > 0.09f)
        assertTrue(t.speechEnergySeen)

        // Attack is instant, decay is smoothed: a quiet frame lowers but
        // does not zero the level.
        capture.feed(2_400, amplitude = 0)
        assertTrue(t.inputLevel.value > 0f)
        assertTrue(t.inputLevel.value < 0.09f)
    }

    @Test
    fun `five seconds of dead silence surfaces the no-audio banner and a spike clears it`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture)

        capture.feed(2_400, amplitude = 0)
        nowMillis.addAndGet(4_000)
        capture.feed(2_400, amplitude = 0)
        assertEquals("4 s of silence is not enough", "", t.errorMessage.value)

        nowMillis.addAndGet(1_500)
        capture.feed(2_400, amplitude = 0)
        assertEquals(OpenAIRealtimeTranscriber.NO_AUDIO_MESSAGE, t.errorMessage.value)
        assertTrue("still listening: it is a hint, not a failure", t.isListening.value)
        assertTrue(diagText(t).contains("no audio energy"))

        // Any energy spike resets the window and clears the banner.
        capture.feed(2_400, amplitude = 1_000)
        assertEquals("", t.errorMessage.value)
        nowMillis.addAndGet(4_000)
        capture.feed(2_400, amplitude = 0)
        assertEquals("window restarts after the spike", "", t.errorMessage.value)
    }

    @Test
    fun `trailing silence after real speech never claims the microphone is dead`() {
        val serverSide = ServerSide()
        val capture = FakeCapture()
        val t = openSession(serverSide, capture)

        capture.feed(2_400, amplitude = 3_000)
        assertTrue(t.speechEnergySeen)

        // Five seconds of quiet is an ordinary end-of-turn after audible
        // speech. It must not reuse the never-heard-audio diagnostic.
        nowMillis.addAndGet(OpenAIRealtimeTranscriber.NO_AUDIO_WINDOW_MILLIS + 500)
        capture.feed(2_400, amplitude = 0)

        assertEquals("", t.errorMessage.value)
        assertFalse(diagText(t).contains("no audio energy"))
        assertTrue(t.isListening.value)
    }

    @Test
    fun `sessionReady flag follows the socket lifecycle`() {
        val serverSide = ServerSide()
        val t = openSession(serverSide)
        assertFalse(t.sessionReady)
        serverSide.send("""{"type":"session.created","session":{}}""")
        await { t.sessionReady }
        t.stop()
        assertFalse(t.sessionReady)
    }
}
