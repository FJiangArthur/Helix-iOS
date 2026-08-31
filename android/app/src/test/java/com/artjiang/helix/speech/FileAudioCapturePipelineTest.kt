package com.artjiang.helix.speech

import com.artjiang.helix.ai.KeyStore
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.util.Base64
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * E2E-shaped harness validation against the MockWebServer double: the real
 * q1 fixture WAV streams through [FileAudioCapture] (gated on SessionReady,
 * real-time pace, real periodic flush) into the real transcriber, and the
 * server side must receive every PCM byte of the file as
 * `input_audio_buffer.append` frames. This is the same plumbing
 * [RealtimeLiveE2E] points at api.openai.com.
 */
class FileAudioCapturePipelineTest {

    private lateinit var server: MockWebServer
    private val client = OkHttpClient()
    private val scheduler = ScheduledThreadPoolExecutor(1)

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        scheduler.shutdownNow()
        server.shutdown()
        client.dispatcher.executorService.shutdown()
    }

    private class ServerSide : WebSocketListener() {
        val messages = LinkedBlockingQueue<String>()
        val opened = CountDownLatch(1)
        val closeCodes = LinkedBlockingQueue<Int>()
        @Volatile var socket: WebSocket? = null

        override fun onOpen(webSocket: WebSocket, response: Response) {
            socket = webSocket
            opened.countDown()
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            messages.add(text)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            closeCodes.add(code)
            webSocket.close(1000, null)
        }

        fun send(text: String) = socket!!.send(text)
    }

    private fun fixtureFile(): File {
        val bytes = requireNotNull(javaClass.getResourceAsStream("/q1_24k.wav")) {
            "q1_24k.wav missing from src/test/resources"
        }.use { it.readBytes() }
        return File.createTempFile("q1_24k", ".wav").apply {
            deleteOnExit()
            writeBytes(bytes)
        }
    }

    @Test
    fun `q1 fixture streams gated on SessionReady and every pcm byte reaches the socket`() {
        val wav = fixtureFile()
        val pcm = FileAudioCapture.parseWav(wav.readBytes())
        assertEquals(24_000, pcm.sampleRateHz)

        val serverSide = ServerSide()
        server.enqueue(MockResponse().withWebSocketUpgrade(serverSide))

        val transcriberRef = AtomicReference<OpenAIRealtimeTranscriber>()
        val capture = FileAudioCapture(
            file = wav,
            awaitGate = { transcriberRef.get()?.sessionReady == true },
        )
        val transcriber = OpenAIRealtimeTranscriber(
            keyStore = object : KeyStore {
                override fun keyFor(kind: String): String? = if (kind == "OPENAI") "sk-test" else null
            },
            capture = capture,
            client = client,
            url = server.url("/v1/realtime?intent=transcription").toString(),
            model = { "gpt-4o-mini-transcribe" },
            language = "en",
            sendScheduler = scheduler, // real: the 100 ms periodic flush runs
            logSink = {},
            connectWatchdogMillis = 0, // this test deliberately delays SessionReady
            firstDeltaWatchdogMillis = 0, // the double never sends transcripts
        )
        transcriberRef.set(transcriber)

        try {
            transcriber.start()
            assertTrue(serverSide.opened.await(3, TimeUnit.SECONDS))
            val first = serverSide.messages.poll(3, TimeUnit.SECONDS)
            assertTrue(first!!.contains("\"session.update\""))

            // Gate behavior: with the session not yet ready, the capture must
            // hold — no frames enqueued, so nothing can be dropped from the
            // ring and nothing is appended.
            Thread.sleep(500)
            assertNull("no audio may flow before SessionReady", serverSide.messages.poll(200, TimeUnit.MILLISECONDS))
            assertEquals("gate must hold frames out of the outbox", 0, transcriber.bufferedBytes)
            assertEquals("gate must prevent ring eviction", 0L, transcriber.droppedBytes)

            serverSide.send("""{"type":"session.created","session":{}}""")

            // The fixture is ~1.8 s of 24 kHz speech; with real-time pacing
            // and the 100 ms flush, every PCM byte must arrive within a few
            // seconds (silence frames follow, so the total keeps growing).
            var appendedBytes = 0L
            val deadline = System.currentTimeMillis() + 10_000
            while (appendedBytes < pcm.dataBytes) {
                val remaining = deadline - System.currentTimeMillis()
                assertTrue(
                    "only $appendedBytes of ${pcm.dataBytes} PCM bytes arrived in time",
                    remaining > 0,
                )
                val message = serverSide.messages.poll(remaining, TimeUnit.MILLISECONDS) ?: continue
                val root = Json.parseToJsonElement(message).jsonObject
                assertEquals("input_audio_buffer.append", root["type"]!!.jsonPrimitive.content)
                val bytes = Base64.getDecoder().decode(root["audio"]!!.jsonPrimitive.content)
                assertTrue("append frames must hold whole 16-bit samples", bytes.size % 2 == 0)
                appendedBytes += bytes.size
            }
            // Nothing was lost on the way: the 24 kHz fixture is passthrough
            // (no resampling), so the byte count can only overshoot by the
            // trailing silence, never undershoot.
            assertTrue(appendedBytes >= pcm.dataBytes)
            assertEquals(0L, transcriber.droppedBytes)

            // Stop commits the buffered turn and closes cleanly, exactly as
            // the live harness will.
            transcriber.stop()
            var sawCommit = false
            while (true) {
                val message = serverSide.messages.poll(2, TimeUnit.SECONDS) ?: break
                if (message == RealtimeEvents.audioCommit()) {
                    sawCommit = true
                    break
                }
                // Trailing appends flushed on stop are fine.
                assertTrue(message.contains("input_audio_buffer.append"))
            }
            assertTrue("stop must commit the audible turn", sawCommit)
            assertEquals(1000, serverSide.closeCodes.poll(3, TimeUnit.SECONDS))
        } finally {
            runCatching { transcriber.stop() }
        }
    }
}
