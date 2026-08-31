// Pure, stateful PCM16 mono resampler for feeding 24 kHz audio to the OpenAI
// Realtime API from whatever rate AudioRecord actually opened at.
package com.artjiang.helix.speech

/**
 * Linear-interpolation resampler that carries its phase (and the previous
 * chunk's last sample) across calls, so a stream resampled chunk by chunk is
 * identical to the same stream resampled in one pass — no clicks at chunk
 * seams. When decimating (48 k / 44.1 k → 24 k) the input is first smoothed
 * with a 2-tap average, a cheap anti-alias that is plenty for speech.
 *
 * Not thread-safe: one instance per capture thread.
 */
class PcmResampler(val inputRate: Int, val outputRate: Int) {
    init {
        require(inputRate > 0 && outputRate > 0) { "rates must be positive" }
    }

    val isPassthrough: Boolean = inputRate == outputRate
    private val decimating = inputRate > outputRate

    /**
     * Position of the next output sample relative to the current chunk's
     * index 0, in units of 1/[outputRate] input samples — i.e. the true
     * position is `phase / outputRate`. Integer so the chunked stream lands
     * on exactly the same sample positions as a one-shot pass.
     */
    private var phase = 0L

    /** Last (smoothed) input sample of the previous chunk — the `i == -1` tap. */
    private var carry: Short = 0
    private var primed = false

    /** Last raw input sample of the previous chunk, for the 2-tap pre-filter. */
    private var lastRaw: Short = 0

    /** Resamples the first [length] samples of [input]; returns a freshly sized array. */
    fun resample(input: ShortArray, length: Int = input.size): ShortArray {
        val n = length.coerceIn(0, input.size)
        if (n == 0) return ShortArray(0)
        if (isPassthrough) return input.copyOf(n)

        val source = if (decimating) smoothed(input, n) else input
        val out = ShortArray((n.toLong() * outputRate / inputRate).toInt() + 2)
        var count = 0
        var pos = phase
        val last = n - 1
        val lastPhase = last.toLong() * outputRate
        while (pos <= lastPhase) {
            val i = Math.floorDiv(pos, outputRate.toLong()).toInt()
            val frac = (pos - i.toLong() * outputRate).toDouble() / outputRate
            val a = if (i < 0) carry.toInt() else source[i].toInt()
            val b = if (i + 1 <= last) source[i + 1].toInt() else source[last].toInt()
            out[count++] = (a + (b - a) * frac).toInt().coerceIn(-32768, 32767).toShort()
            pos += inputRate
        }
        phase = pos - n.toLong() * outputRate
        carry = source[last]
        primed = true
        return if (count == out.size) out else out.copyOf(count)
    }

    /** 2-tap moving average, continuous across chunks via [lastRaw]. */
    private fun smoothed(input: ShortArray, n: Int): ShortArray {
        val out = ShortArray(n)
        var prev = if (primed) lastRaw.toInt() else input[0].toInt()
        for (i in 0 until n) {
            val cur = input[i].toInt()
            out[i] = ((prev + cur) / 2).toShort()
            prev = cur
        }
        lastRaw = input[n - 1]
        return out
    }

    /** Forgets carried phase/samples — call when the capture stream restarts. */
    fun reset() {
        phase = 0L
        carry = 0
        lastRaw = 0
        primed = false
    }
}
