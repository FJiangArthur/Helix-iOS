package com.artjiang.helix.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecentTranscriptBufferTest {

    @Test
    fun `keeps entries inside the window oldest first`() {
        var now = 100_000L
        val buffer = RecentTranscriptBuffer(windowMillis = 60_000, clock = { now })
        buffer.append("first")
        now += 30_000
        buffer.append("second")
        assertEquals("first\nsecond", buffer.recent())

        now += 31_000 // "first" is now 61 s old
        assertEquals("second", buffer.recent())
        now += 60_000
        assertEquals("", buffer.recent())
        assertTrue(buffer.isEmpty())
    }

    @Test
    fun `explicit timestamps are honoured`() {
        val buffer = RecentTranscriptBuffer(windowMillis = 1_000, clock = { 0L })
        buffer.append("old", at = 0)
        buffer.append("new", at = 900)
        assertEquals("old\nnew", buffer.recent(now = 999))
        assertEquals("new", buffer.recent(now = 1_500))
    }

    @Test
    fun `drops the oldest lines when over the character cap`() {
        val buffer = RecentTranscriptBuffer(maxChars = 12, clock = { 0L })
        buffer.append("aaaa") // 4
        buffer.append("bbbb") // 9 with newline
        buffer.append("cccc") // 14 → evict "aaaa"
        assertEquals("bbbb\ncccc", buffer.recent())
    }

    @Test
    fun `a single oversized line is truncated to its tail`() {
        val buffer = RecentTranscriptBuffer(maxChars = 5, clock = { 0L })
        buffer.append("abcdefgh")
        assertEquals("defgh", buffer.recent())
    }

    @Test
    fun `blank input is ignored and clear empties everything`() {
        val buffer = RecentTranscriptBuffer(clock = { 0L })
        buffer.append("   ")
        assertTrue(buffer.isEmpty())
        buffer.append("  hello  ")
        assertEquals("hello", buffer.recent())
        buffer.clear()
        assertEquals("", buffer.recent())
    }
}
