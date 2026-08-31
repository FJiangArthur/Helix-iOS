package com.artjiang.helix.speech

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SwitchableAudioCaptureTest {

    private class FakeCapture(override val sampleRateHz: Int = 24_000) : AudioCapture {
        var startCount = 0
        var stopCount = 0
        var lastOnPcm: ((ShortArray, Int) -> Unit)? = null
        var lastOnError: ((String) -> Unit)? = null

        override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
            startCount += 1
            lastOnPcm = onPcm
            lastOnError = onError
        }

        override fun stop() {
            stopCount += 1
        }
    }

    @Test
    fun `start and stop delegate to the current delegate`() {
        val fake = FakeCapture()
        val capture = SwitchableAudioCapture(fake)

        capture.start(onPcm = { _, _ -> }, onError = {})
        assertEquals(1, fake.startCount)

        capture.stop()
        assertEquals(1, fake.stopCount)
    }

    @Test
    fun `sampleRateHz reads through to the delegate`() {
        val capture = SwitchableAudioCapture(FakeCapture(sampleRateHz = 16_000))
        assertEquals(16_000, capture.sampleRateHz)

        capture.swap(FakeCapture(sampleRateHz = 48_000))
        assertEquals(48_000, capture.sampleRateHz)
    }

    @Test
    fun `pcm and error callbacks flow through unchanged`() {
        val fake = FakeCapture()
        val capture = SwitchableAudioCapture(fake)
        var frames = 0
        var error = ""
        capture.start(onPcm = { _, count -> frames = count }, onError = { error = it })

        fake.lastOnPcm?.invoke(ShortArray(480), 480)
        fake.lastOnError?.invoke("boom")

        assertEquals(480, frames)
        assertEquals("boom", error)
    }

    @Test
    fun `second start while running is ignored`() {
        val fake = FakeCapture()
        val capture = SwitchableAudioCapture(fake)
        capture.start(onPcm = { _, _ -> }, onError = {})
        capture.start(onPcm = { _, _ -> }, onError = {})
        assertEquals(1, fake.startCount)
    }

    @Test
    fun `stop without start still forwards to the delegate`() {
        val fake = FakeCapture()
        val capture = SwitchableAudioCapture(fake)
        capture.stop()
        assertEquals(1, fake.stopCount)
    }

    @Test
    fun `swap while stopped replaces the delegate for the next start`() {
        val first = FakeCapture()
        val second = FakeCapture()
        val capture = SwitchableAudioCapture(first)

        capture.start(onPcm = { _, _ -> }, onError = {})
        capture.stop()
        capture.swap(second)
        assertSame(second, capture.current)

        capture.start(onPcm = { _, _ -> }, onError = {})
        assertEquals(1, first.startCount)
        assertEquals(1, second.startCount)
    }

    @Test
    fun `swap while running throws and keeps the old delegate`() {
        val first = FakeCapture()
        val second = FakeCapture()
        val capture = SwitchableAudioCapture(first)
        capture.start(onPcm = { _, _ -> }, onError = {})

        assertThrows(IllegalStateException::class.java) { capture.swap(second) }
        assertSame(first, capture.current)
        assertEquals(0, second.startCount)
    }

    @Test
    fun `swap back to the original delegate restarts it cleanly`() {
        val mic = FakeCapture()
        val file = FakeCapture()
        val capture = SwitchableAudioCapture(mic)

        // Injection cycle: stop, swap in file, run, stop, swap back.
        capture.swap(file)
        capture.start(onPcm = { _, _ -> }, onError = {})
        capture.stop()
        capture.swap(mic)
        capture.start(onPcm = { _, _ -> }, onError = {})

        assertEquals(1, file.startCount)
        assertEquals(1, file.stopCount)
        assertEquals(1, mic.startCount)
    }

    @Test
    fun `guard helper allows injection only in debug builds with a key`() {
        assertTrue(com.artjiang.helix.HelixBridge.shouldStartDebugInjection(isDebugBuild = true, hasOpenAiKey = true))
        assertFalse(com.artjiang.helix.HelixBridge.shouldStartDebugInjection(isDebugBuild = false, hasOpenAiKey = true))
        assertFalse(com.artjiang.helix.HelixBridge.shouldStartDebugInjection(isDebugBuild = true, hasOpenAiKey = false))
        assertFalse(com.artjiang.helix.HelixBridge.shouldStartDebugInjection(isDebugBuild = false, hasOpenAiKey = false))
    }
}
