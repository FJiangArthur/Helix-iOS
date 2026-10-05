package com.artjiang.helix.conversate

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.HudPaginator
import org.junit.Assert.assertEquals
import org.junit.Test

class CaptionBufferTest {
    private fun seg(t: String, final: Boolean) = TranscriptSegment(t, final, 0)

    @Test
    fun `partial replaces partial, final commits`() {
        val b = CaptionBuffer(HudPaginator(maxCharactersPerLine = 20, linesPerPage = 5))
        b.onSegment(seg("hello", false))
        b.onSegment(seg("hello there", false))
        assertEquals(listOf("hello there"), b.lines())
        b.onSegment(seg("Hello there.", true))
        b.onSegment(seg("How", false))
        assertEquals(listOf("Hello there. How"), b.lines())
    }

    @Test
    fun `keeps only the newest lines`() {
        val b = CaptionBuffer(HudPaginator(maxCharactersPerLine = 10, linesPerPage = 5), maxLines = 2)
        listOf("aaaa bbbb", "cccc dddd", "eeee ffff").forEach { b.onSegment(seg(it, true)) }
        assertEquals(listOf("cccc dddd", "eeee ffff"), b.lines())
    }

    @Test
    fun `blank partial ignored and clear empties`() {
        val b = CaptionBuffer()
        b.onSegment(seg("  ", false))
        assertEquals(emptyList<String>(), b.lines())
        b.onSegment(seg("x", true)); b.clear()
        assertEquals(emptyList<String>(), b.lines())
    }
}
