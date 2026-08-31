package com.artjiang.helix.speech

import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.core.TranscriptSegment
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.io.FileWriter
import java.io.PrintWriter
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference

/**
 * Live end-to-end test against the real OpenAI Realtime API — the Layer 1
 * instrument from the E2E verification plan. It streams a spoken fixture WAV
 * through [FileAudioCapture] into the real [OpenAIRealtimeTranscriber]
 * (production client, production `wss://api.openai.com` URL, production
 * watchdogs) and logs EVERY raw server frame verbatim to a .jsonl file, so a
 * stall shows exactly which event the GA server sent and where the client
 * stopped following.
 *
 * Skipped automatically (JUnit assumption) unless `OPENAI_API_KEY` is set,
 * so CI and normal test runs never touch the network.
 *
 * ### How to run
 *
 * ```bash
 * cd android
 * OPENAI_API_KEY=sk-... \
 * HELIX_E2E_WAV=/path/to/q1_24k.wav \
 * JAVA_HOME=/opt/homebrew/opt/openjdk@17 \
 * ./gradlew :app:testDebugUnitTest --tests "*RealtimeLiveE2E*"
 * ```
 *
 * Environment:
 * - `OPENAI_API_KEY`  (required) — real key; never logged, never committed.
 * - `HELIX_E2E_WAV`   (required) — 16-bit mono PCM WAV with a clearly spoken
 *   question (the scratchpad fixture `q1_24k.wav`: "What is the capital of
 *   France?").
 * - `HELIX_E2E_LOG`   (optional) — where the raw server frames go; defaults
 *   to `app/build/realtime-e2e.jsonl`.
 * - `HELIX_E2E_EXPECT` (optional) — expected transcript; defaults to
 *   "what is the capital of france". The assertion is a >= 60% lowercase
 *   word-set overlap, not an exact match.
 * - `HELIX_E2E_MODEL` (optional) — overrides the production default model
 *   ([RealtimeEvents.DEFAULT_MODEL]) to bisect model-specific behavior.
 *
 * Assertions: SessionReady within 5 s of start; first partial within 10 s of
 * streaming start (playback is gated on SessionReady so the 5 s outbox ring
 * cannot evict the opening words); a final transcript within 20 s whose word
 * set overlaps the expectation. Any transcriber error (including the
 * watchdogs' actionable messages) fails immediately with that message.
 */
class RealtimeLiveE2E {

    @Test
    fun `live realtime transcription of the fixture question`() {
        val apiKey = System.getenv("OPENAI_API_KEY")
        assumeTrue("OPENAI_API_KEY not set — skipping live E2E", apiKey != null)
        val wavPath = System.getenv("HELIX_E2E_WAV")
        assumeTrue("HELIX_E2E_WAV not set — skipping live E2E", wavPath != null)
        val wav = File(wavPath!!)
        assumeTrue("HELIX_E2E_WAV does not exist: $wavPath", wav.isFile)

        val logFile = File(System.getenv("HELIX_E2E_LOG") ?: "build/realtime-e2e.jsonl")
        logFile.parentFile?.mkdirs()
        val expectedWords = (System.getenv("HELIX_E2E_EXPECT") ?: DEFAULT_EXPECT)
            .lowercase(Locale.ROOT).split(NON_WORD).filter { it.isNotEmpty() }.toSet()
        val modelOverride = System.getenv("HELIX_E2E_MODEL")

        val transcriberRef = AtomicReference<OpenAIRealtimeTranscriber>()
        val capture = FileAudioCapture(
            file = wav,
            // Hold playback until the session is configured: otherwise the
            // 5 s outbox ring can evict the opening words while connecting.
            awaitGate = { transcriberRef.get()?.sessionReady == true },
        )
        val segments = CopyOnWriteArrayList<TranscriptSegment>()
        val transcriber = OpenAIRealtimeTranscriber(
            keyStore = object : KeyStore {
                override fun keyFor(kind: String): String? = if (kind == "OPENAI") apiKey else null
            },
            capture = capture,
            // Everything else stays production: defaultClient, DEFAULT_URL,
            // default scheduler, default watchdog timeouts.
            model = { modelOverride ?: RealtimeEvents.DEFAULT_MODEL },
            logSink = { line -> println("[HelixRealtime] $line") },
        )
        transcriberRef.set(transcriber)
        transcriber.onSegment = { segments += it }

        PrintWriter(FileWriter(logFile, false), true).use { writer ->
            transcriber.onRawFrame = { frame -> synchronized(writer) { writer.println(frame) } }
            try {
                transcriber.start()
                awaitOrFail(transcriber, 5_000, "SessionReady within 5 s") { transcriber.sessionReady }
                val streamingStartedAt = System.currentTimeMillis()

                awaitOrFail(transcriber, 10_000, "first partial within 10 s of streaming start") {
                    segments.isNotEmpty()
                }
                val firstPartialMillis = System.currentTimeMillis() - streamingStartedAt
                println("[RealtimeLiveE2E] first partial after ${firstPartialMillis} ms: '${segments.first().text}'")

                awaitOrFail(transcriber, 20_000, "final transcript within 20 s") {
                    segments.any { it.isFinal }
                }
                val finalText = segments.last { it.isFinal }.text
                println("[RealtimeLiveE2E] final transcript: '$finalText'")
                println("[RealtimeLiveE2E] raw frame log: ${logFile.absolutePath}")

                val actualWords = finalText.lowercase(Locale.ROOT).split(NON_WORD).filter { it.isNotEmpty() }.toSet()
                val overlap = expectedWords.count { it in actualWords }.toDouble() / expectedWords.size
                assertTrue(
                    "word overlap ${"%.0f".format(overlap * 100)}% < 60% — got '$finalText', expected ~'${expectedWords.joinToString(" ")}'",
                    overlap >= 0.6,
                )
            } finally {
                transcriber.stop()
                println("[RealtimeLiveE2E] diagnostics:\n  ${transcriber.diagnostics.value.joinToString("\n  ")}")
            }
        }
    }

    /**
     * Polls [condition] until [timeoutMillis]; fails immediately (with the
     * transcriber's own actionable message) if the source errors out first.
     * The benign trailing-silence "no audio" hint is not an error here: the
     * fixture ends and silence frames keep flowing by design.
     */
    private fun awaitOrFail(
        transcriber: OpenAIRealtimeTranscriber,
        timeoutMillis: Long,
        what: String,
        condition: () -> Boolean,
    ) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (!condition()) {
            val error = transcriber.errorMessage.value
            if (error.isNotEmpty() && error != OpenAIRealtimeTranscriber.NO_AUDIO_MESSAGE) {
                throw AssertionError("transcriber failed while waiting for $what: $error")
            }
            if (System.currentTimeMillis() > deadline) {
                throw AssertionError(
                    "timed out waiting for $what; diagnostics:\n  " +
                        transcriber.diagnostics.value.joinToString("\n  "),
                )
            }
            Thread.sleep(25)
        }
    }

    private companion object {
        const val DEFAULT_EXPECT = "what is the capital of france"
        val NON_WORD = Regex("[^a-z0-9']+")
    }
}
