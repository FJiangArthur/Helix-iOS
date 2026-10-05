package com.artjiang.helix.conversate

import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateIntentTest {
    private fun f(i: Int, side: G1TouchpadSide = G1TouchpadSide.LEFT) = G1TouchpadFrame(i, side)

    @Test
    fun `taps page, double-tap is back`() {
        assertEquals(ConversateIntent.NEXT, G1InputMapper.map(f(1, G1TouchpadSide.RIGHT), false))
        assertEquals(ConversateIntent.PREV, G1InputMapper.map(f(1, G1TouchpadSide.LEFT), false))
        assertEquals(ConversateIntent.BACK, G1InputMapper.map(f(0), false))
    }

    @Test
    fun `long press is menu outside lists and select inside`() {
        assertEquals(ConversateIntent.MENU, G1InputMapper.map(f(23), selectContext = false))
        assertEquals(ConversateIntent.SELECT, G1InputMapper.map(f(23), selectContext = true))
    }

    @Test
    fun `long press release is swallowed`() {
        assertNull(G1InputMapper.map(f(24), false))
        assertNull(G1InputMapper.map(f(24), true))
    }

    @Test
    fun `head events map`() {
        assertEquals(ConversateIntent.HEAD_UP, G1InputMapper.map(G1StatusEvent.HeadUp))
        assertEquals(ConversateIntent.HEAD_DOWN, G1InputMapper.map(G1StatusEvent.HeadDown))
        assertNull(G1InputMapper.map(null))
    }

    @Test
    fun `same intent from two sources inside window counts once`() {
        var now = 0L
        val d = IntentDeduper(clock = { now })
        assertTrue(d.accept(ConversateIntent.SELECT, IntentSource.R1))
        now = 100
        assertFalse(d.accept(ConversateIntent.SELECT, IntentSource.G1_TOUCHPAD))
        now = 400
        assertTrue(d.accept(ConversateIntent.SELECT, IntentSource.G1_TOUCHPAD))
    }

    @Test
    fun `same source repeats are kept`() {
        var now = 0L
        val d = IntentDeduper(clock = { now })
        assertTrue(d.accept(ConversateIntent.NEXT, IntentSource.G1_TOUCHPAD))
        now = 50
        assertTrue(d.accept(ConversateIntent.NEXT, IntentSource.G1_TOUCHPAD))
    }
}
