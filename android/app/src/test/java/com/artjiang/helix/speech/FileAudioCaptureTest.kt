package com.artjiang.helix.speech

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class FileAudioCaptureTest {

    // MARK: - WAV builder

    /** Minimal RIFF/WAVE writer; [extraChunkBeforeData] mimics ffmpeg's LIST chunk. */
    private fun wavBytes(
        rate: Int,
        samples: ShortArray,
        channels: Int = 1,
        bitsPerSample: Int = 16,
        audioFormat: Int = 1,
        extraChunkBeforeData: Boolean = false,
    ): ByteArray {
        val data = ByteArrayOutputStream()
        fun tag(s: String) = data.write(s.toByteArray(Charsets.US_ASCII))
        fun le16(v: Int) {
            data.write(v and 0xFF); data.write((v shr 8) and 0xFF)
        }
        fun le32(v: Int) {
            data.write(v and 0xFF); data.write((v shr 8) and 0xFF)
            data.write((v shr 16) and 0xFF); data.write((v shr 24) and 0xFF)
        }
        val dataBytes = samples.size * 2
        val extra = if (extraChunkBeforeData) 8 + 4 else 0
        tag("RIFF"); le32(4 + 24 + extra + 8 + dataBytes); tag("WAVE")
        tag("fmt "); le32(16)
        le16(audioFormat); le16(channels); le32(rate)
        le32(rate * channels * bitsPerSample / 8); le16(channels * bitsPerSample / 8); le16(bitsPerSample)
        if (extraChunkBeforeData) {
            tag("LIST"); le32(4); tag("INFO")
        }
        tag("data"); le32(dataBytes)
        for (s in samples) le16(s.toInt() and 0xFFFF)
        return data.toByteArray()
    }

    private fun tempWav(bytes: ByteArray): File =
        File.createTempFile("fixture", ".wav").apply {
            deleteOnExit()
            writeBytes(bytes)
        }

    /** Fake time: sleeper advances the clock by exactly what was requested. */
    private class FakeTime {
        val nanos = AtomicLong(0)
        val sleeps = CopyOnWriteArrayList<Long>()
        val sleeper: (Long) -> Unit = { millis ->
            sleeps += millis
            nanos.addAndGet(millis * 1_000_000L)
        }
        val nanoTime: () -> Long = { nanos.get() }
    }

    private class Frames {
        val chunks = CopyOnWriteArrayList<ShortArray>()
        val onPcm: (ShortArray, Int) -> Unit = { buffer, length ->
            chunks += buffer.copyOf(length)
        }
        fun totalSamples(): Int = chunks.sumOf { it.size }
    }

    private fun awaitTrue(timeoutMillis: Long = 3_000, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (!condition()) {
            if (System.currentTimeMillis() > deadline) throw AssertionError("condition not met in $timeoutMillis ms")
            Thread.sleep(5)
        }
    }

    // MARK: - Header parsing

    @Test
    fun `parses a 16-bit mono wav and exposes the header sample rate`() {
        val pcm = FileAudioCapture.parseWav(wavBytes(8_000, ShortArray(400) { it.toShort() }))
        assertEquals(8_000, pcm.sampleRateHz)
        assertEquals(800, pcm.dataBytes)
    }

    @Test
    fun `skips unknown chunks before data like ffmpeg LIST INFO`() {
        val pcm = FileAudioCapture.parseWav(
            wavBytes(24_000, ShortArray(240) { 100 }, extraChunkBeforeData = true),
        )
        assertEquals(24_000, pcm.sampleRateHz)
        assertEquals(480, pcm.dataBytes)
    }

    @Test
    fun `parses the checked-in q1 fixture`() {
        val stream = requireNotNull(javaClass.getResourceAsStream("/q1_24k.wav")) { "fixture missing" }
        val pcm = FileAudioCapture.parseWav(stream.use { it.readBytes() })
        assertEquals(24_000, pcm.sampleRateHz)
        assertTrue(pcm.dataBytes > 24_000) // more than half a second of speech
    }

    @Test
    fun `rejects stereo, 8-bit, compressed, and non-riff files`() {
        val mono = ShortArray(160)
        assertThrows { FileAudioCapture.parseWav(wavBytes(8_000, mono, channels = 2)) }
        assertThrows { FileAudioCapture.parseWav(wavBytes(8_000, mono, bitsPerSample = 8)) }
        assertThrows { FileAudioCapture.parseWav(wavBytes(8_000, mono, audioFormat = 3)) }
        assertThrows { FileAudioCapture.parseWav("not a wav at all".toByteArray()) }
        assertThrows { FileAudioCapture.parseWav(ByteArray(0)) }
        // Truncated: header claims more data than the file holds.
        val truncated = wavBytes(8_000, mono).copyOf(60)
        assertThrows { FileAudioCapture.parseWav(truncated) }
    }

    private fun assertThrows(block: () -> Unit) {
        try {
            block()
        } catch (expected: IOException) {
            return
        }
        throw AssertionError("expected IOException")
    }

    // MARK: - Streaming

    @Test
    fun `streams 20ms frames then silence until stop`() {
        val time = FakeTime()
        val frames = Frames()
        // 400 samples at 8 kHz = 50 ms → frames of 160, 160, 80, then silence frames of 160.
        val capture = FileAudioCapture(
            tempWav(wavBytes(8_000, ShortArray(400) { (it + 1).toShort() })),
            sleeper = time.sleeper,
            nanoTime = time.nanoTime,
        )
        val errors = CopyOnWriteArrayList<String>()
        capture.start(frames.onPcm) { errors += it }
        assertEquals(8_000, capture.sampleRateHz)
        awaitTrue { frames.chunks.size >= 6 }
        capture.stop()

        assertTrue(errors.isEmpty())
        assertEquals(160, frames.chunks[0].size)
        assertEquals(160, frames.chunks[1].size)
        assertEquals(80, frames.chunks[2].size)
        // Content round-trips: first sample of the second frame is sample 161.
        assertEquals(1, frames.chunks[0][0].toInt())
        assertEquals(161, frames.chunks[1][0].toInt())
        assertEquals(400, frames.chunks[2][79].toInt())
        // Silence frames afterwards: full-size and all zero.
        for (i in 3 until frames.chunks.size) {
            assertEquals(160, frames.chunks[i].size)
            assertTrue("frame $i should be silence", frames.chunks[i].all { it.toInt() == 0 })
        }
    }

    @Test
    fun `paces frames on a 20ms real-time grid`() {
        val time = FakeTime()
        val frames = Frames()
        val capture = FileAudioCapture(
            tempWav(wavBytes(24_000, ShortArray(2_400) { 500 })), // 100 ms = 5 frames
            sleeper = time.sleeper,
            nanoTime = time.nanoTime,
        )
        capture.start(frames.onPcm) { throw AssertionError(it) }
        awaitTrue { frames.chunks.size >= 8 }
        capture.stop()
        // Frame 0 is emitted immediately (its slot is t=0); every later frame
        // requests exactly one 20 ms sleep because the fake clock advances
        // only inside the sleeper.
        assertTrue("sleeps: ${time.sleeps}", time.sleeps.size >= 7)
        time.sleeps.forEach { assertEquals(FileAudioCapture.FRAME_MILLIS, it) }
    }

    @Test
    fun `gate holds playback until it opens`() {
        val gate = AtomicBoolean(false)
        val frames = Frames()
        // Real clock on purpose: the 10 s gate budget must not elapse while
        // this test holds the gate closed for a few hundred milliseconds.
        val capture = FileAudioCapture(
            tempWav(wavBytes(24_000, ShortArray(480) { 42 })),
            awaitGate = { gate.get() },
        )
        capture.start(frames.onPcm) { throw AssertionError(it) }
        Thread.sleep(150)
        assertEquals("no frames while the gate is closed", 0, frames.chunks.size)

        gate.set(true)
        awaitTrue { frames.chunks.isNotEmpty() }
        capture.stop()
        assertEquals(42, frames.chunks[0][0].toInt())
    }

    @Test
    fun `gate gives up after ten seconds and streams anyway`() {
        val time = FakeTime()
        val frames = Frames()
        val capture = FileAudioCapture(
            tempWav(wavBytes(24_000, ShortArray(480) { 7 })),
            awaitGate = { false }, // never opens
            sleeper = time.sleeper,
            nanoTime = time.nanoTime,
        )
        capture.start(frames.onPcm) { throw AssertionError(it) }
        awaitTrue { frames.chunks.isNotEmpty() }
        capture.stop()
        // The poll loop burned through the 10 s budget on the fake clock
        // (200 × 50 ms) before streaming began.
        val gatePolls = time.sleeps.count { it == FileAudioCapture.GATE_POLL_MILLIS }
        assertTrue("polled $gatePolls times", gatePolls >= (FileAudioCapture.GATE_TIMEOUT_MILLIS / FileAudioCapture.GATE_POLL_MILLIS).toInt())
        assertEquals(7, frames.chunks[0][0].toInt())
    }

    @Test
    fun `malformed wav reports onError and emits nothing`() {
        val frames = Frames()
        val error = AtomicReference<String>()
        val capture = FileAudioCapture(tempWav("garbage garbage garbage".toByteArray()))
        capture.start(frames.onPcm) { error.set(it) }
        assertEquals("Not a RIFF/WAVE file", error.get())
        Thread.sleep(50)
        assertEquals(0, frames.chunks.size)
        capture.stop() // must be a safe no-op
    }

    @Test
    fun `missing file reports onError`() {
        val error = AtomicReference<String>()
        val capture = FileAudioCapture(File("/nonexistent/helix-e2e.wav"))
        capture.start({ _, _ -> throw AssertionError("no frames expected") }) { error.set(it) }
        assertTrue("error should be reported", !error.get().isNullOrBlank())
    }

    @Test
    fun `stop from within the callback does not deadlock`() {
        val time = FakeTime()
        val stopped = CountDownLatch(1)
        val captureRef = AtomicReference<FileAudioCapture>()
        val capture = FileAudioCapture(
            tempWav(wavBytes(24_000, ShortArray(480) { 5 })),
            sleeper = time.sleeper,
            nanoTime = time.nanoTime,
        )
        captureRef.set(capture)
        capture.start({ _, _ ->
            captureRef.get().stop()
            stopped.countDown()
        }) { throw AssertionError(it) }
        assertTrue(stopped.await(3, TimeUnit.SECONDS))
        capture.stop()
    }
}
