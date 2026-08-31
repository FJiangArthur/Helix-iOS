package com.artjiang.helix.speech

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

class PcmResamplerTest {

    private fun sine(rate: Int, seconds: Double, hz: Double = 440.0): ShortArray {
        val n = (rate * seconds).toInt()
        return ShortArray(n) { i -> (sin(2 * PI * hz * i / rate) * 8000).toInt().toShort() }
    }

    @Test
    fun `same rate is passthrough`() {
        val resampler = PcmResampler(24_000, 24_000)
        val input = sine(24_000, 0.02)
        val out = resampler.resample(input)
        assertTrue(resampler.isPassthrough)
        assertArrayEquals(input, out)
    }

    @Test
    fun `upsampling 16k to 24k yields the expected length over many chunks`() {
        val resampler = PcmResampler(16_000, 24_000)
        var total = 0
        repeat(50) { total += resampler.resample(ShortArray(320) { 100 }).size } // 50 × 20 ms
        assertTrue("got $total", abs(total - 50 * 480) <= 1)
    }

    @Test
    fun `downsampling 48k to 24k halves the sample count`() {
        val resampler = PcmResampler(48_000, 24_000)
        val out = resampler.resample(ShortArray(960) { 500 })
        assertEquals(480, out.size)
    }

    @Test
    fun `dc input stays dc`() {
        val resampler = PcmResampler(44_100, 24_000)
        repeat(5) {
            val out = resampler.resample(ShortArray(882) { 1234 })
            assertTrue(out.isNotEmpty())
            assertTrue(out.all { it.toInt() == 1234 })
        }
    }

    @Test
    fun `chunked output matches one-shot output at the seams`() {
        val input = sine(16_000, 0.1)
        val oneShot = PcmResampler(16_000, 24_000).resample(input)

        val chunked = PcmResampler(16_000, 24_000)
        val pieces = mutableListOf<Short>()
        var offset = 0
        val chunkSizes = listOf(320, 160, 480, 320, 320)
        for (size in chunkSizes) {
            val end = minOf(offset + size, input.size)
            pieces += chunked.resample(input.copyOfRange(offset, end)).toList()
            offset = end
        }
        if (offset < input.size) pieces += chunked.resample(input.copyOfRange(offset, input.size)).toList()

        assertArrayEquals(oneShot, pieces.toShortArray())
    }

    @Test
    fun `honours the length argument and ignores the tail`() {
        val resampler = PcmResampler(48_000, 24_000)
        val buffer = ShortArray(960) { if (it < 480) 1000 else 32000 }
        val out = resampler.resample(buffer, 480)
        assertEquals(240, out.size)
        assertTrue(out.all { it.toInt() == 1000 })
    }
}
