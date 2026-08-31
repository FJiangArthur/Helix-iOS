// WAV-file-backed AudioCapture for the E2E transcription harness: streams a
// 16-bit mono PCM WAV in 20 ms frames at real-time pace, then keeps emitting
// silence until stop() so server VAD sees the trailing quiet it needs to
// close the turn. Pure JVM (java.io only) so host-side tests can drive the
// real OpenAIRealtimeTranscriber without a device.
package com.artjiang.helix.speech

import java.io.File
import java.io.IOException

/**
 * [AudioCapture] that plays a WAV file instead of the microphone.
 *
 * - Any sample rate is accepted; [sampleRateHz] comes from the header (the
 *   consumer resamples, exactly as it does for a real microphone).
 * - Frames are emitted on a dedicated thread every [FRAME_MILLIS] ms; after
 *   the file is exhausted, zero (silence) frames continue at the same
 *   cadence until [stop] — server VAD only commits a turn after silence.
 * - [awaitGate], when set, holds playback until it returns true (polled
 *   every [GATE_POLL_MILLIS] ms, at most [GATE_TIMEOUT_MILLIS] ms). The
 *   harness gates on the realtime session becoming ready so the 5 s outbox
 *   ring cannot evict the opening words while the socket is still
 *   configuring.
 * - [sleeper]/[nanoTime] are injectable so unit tests can run pace-free with
 *   a fake clock.
 *
 * A malformed or unsupported WAV (not RIFF/WAVE, compressed, stereo, not
 * 16-bit) reports through `onError` and never starts the thread.
 */
class FileAudioCapture(
    private val file: File,
    private val awaitGate: (() -> Boolean)? = null,
    private val sleeper: (Long) -> Unit = Thread::sleep,
    private val nanoTime: () -> Long = System::nanoTime,
) : AudioCapture {

    @Volatile
    override var sampleRateHz: Int = RealtimeEvents.SAMPLE_RATE
        private set

    @Volatile
    private var running = false
    private var thread: Thread? = null

    override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
        if (running) return
        val pcm = try {
            parseWav(file.readBytes())
        } catch (e: IOException) {
            onError(e.message ?: "unreadable WAV file")
            return
        }
        sampleRateHz = pcm.sampleRateHz
        running = true
        thread = Thread({ stream(pcm, onPcm) }, "helix-file-capture").apply {
            isDaemon = true
            start()
        }
    }

    override fun stop() {
        running = false
        val t = thread
        thread = null
        if (t != null && t !== Thread.currentThread()) {
            runCatching { t.join(1_000) }
        }
    }

    private fun stream(pcm: WavPcm, onPcm: (ShortArray, Int) -> Unit) {
        awaitGate?.let { gate ->
            val deadline = nanoTime() + GATE_TIMEOUT_MILLIS * 1_000_000L
            while (running && !gate() && nanoTime() < deadline) sleeper(GATE_POLL_MILLIS)
        }
        if (!running) return

        val frameSamples = maxOf(1, (pcm.sampleRateHz.toLong() * FRAME_MILLIS / 1_000L).toInt())
        val frame = ShortArray(frameSamples)
        val bytes = pcm.bytes
        val end = pcm.dataOffset + pcm.dataBytes
        var offset = pcm.dataOffset
        val startNanos = nanoTime()
        var frameIndex = 0L
        var silenced = false

        while (running) {
            val remainingSamples = (end - offset) / 2
            val count: Int
            if (remainingSamples > 0) {
                count = minOf(frameSamples, remainingSamples)
                for (i in 0 until count) {
                    val lo = bytes[offset + 2 * i].toInt() and 0xFF
                    val hi = bytes[offset + 2 * i + 1].toInt()
                    frame[i] = ((hi shl 8) or lo).toShort()
                }
                offset += count * 2
            } else {
                count = frameSamples
                if (!silenced) {
                    frame.fill(0)
                    silenced = true
                }
            }
            pace(startNanos, frameIndex)
            if (!running) return
            onPcm(frame, count)
            frameIndex += 1
        }
    }

    /** Sleeps until this frame's slot on the real-time grid (never drifts). */
    private fun pace(startNanos: Long, frameIndex: Long) {
        val targetNanos = startNanos + frameIndex * FRAME_MILLIS * 1_000_000L
        val aheadMillis = (targetNanos - nanoTime()) / 1_000_000L
        if (aheadMillis > 0) sleeper(aheadMillis)
    }

    /** Parsed 16-bit mono PCM payload inside a RIFF/WAVE container. */
    internal class WavPcm(
        val bytes: ByteArray,
        val sampleRateHz: Int,
        val dataOffset: Int,
        val dataBytes: Int,
    )

    companion object {
        const val FRAME_MILLIS = 20L
        const val GATE_POLL_MILLIS = 50L
        const val GATE_TIMEOUT_MILLIS = 10_000L

        /**
         * Strict-enough RIFF walk: requires a PCM (format 1), mono, 16-bit
         * `fmt ` chunk and a `data` chunk; skips everything else (ffmpeg
         * emits a LIST/INFO chunk before `data`). Throws [IOException] with
         * a human-readable reason on anything malformed.
         */
        @Throws(IOException::class)
        internal fun parseWav(bytes: ByteArray): WavPcm {
            if (bytes.size < 12 || !matches(bytes, 0, "RIFF") || !matches(bytes, 8, "WAVE")) {
                throw IOException("Not a RIFF/WAVE file")
            }
            var pos = 12
            var rate = -1
            var dataOffset = -1
            var dataBytes = -1
            while (pos + 8 <= bytes.size) {
                val id = String(bytes, pos, 4, Charsets.US_ASCII)
                val size = le32(bytes, pos + 4)
                if (size < 0 || pos + 8 + size > bytes.size) {
                    throw IOException("Corrupt WAV chunk '$id' (size $size)")
                }
                when (id) {
                    "fmt " -> {
                        if (size < 16) throw IOException("Corrupt WAV fmt chunk")
                        val format = le16(bytes, pos + 8)
                        val channels = le16(bytes, pos + 10)
                        rate = le32(bytes, pos + 12)
                        val bits = le16(bytes, pos + 22)
                        if (format != 1) throw IOException("Unsupported WAV: not linear PCM (format $format)")
                        if (channels != 1) throw IOException("Unsupported WAV: $channels channels (need mono)")
                        if (bits != 16) throw IOException("Unsupported WAV: $bits-bit samples (need 16-bit)")
                        if (rate <= 0) throw IOException("Unsupported WAV: sample rate $rate")
                    }

                    "data" -> {
                        dataOffset = pos + 8
                        dataBytes = size - (size % 2) // whole 16-bit samples only
                    }
                }
                pos += 8 + size + (size % 2) // RIFF chunks are word-aligned
            }
            if (rate <= 0) throw IOException("WAV is missing its fmt chunk")
            if (dataOffset < 0) throw IOException("WAV is missing its data chunk")
            return WavPcm(bytes, rate, dataOffset, dataBytes)
        }

        private fun matches(bytes: ByteArray, offset: Int, tag: String): Boolean {
            if (offset + tag.length > bytes.size) return false
            for (i in tag.indices) {
                if (bytes[offset + i] != tag[i].code.toByte()) return false
            }
            return true
        }

        private fun le16(bytes: ByteArray, offset: Int): Int =
            (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)

        private fun le32(bytes: ByteArray, offset: Int): Int =
            (bytes[offset].toInt() and 0xFF) or
                ((bytes[offset + 1].toInt() and 0xFF) shl 8) or
                ((bytes[offset + 2].toInt() and 0xFF) shl 16) or
                ((bytes[offset + 3].toInt() and 0xFF) shl 24)
    }
}
