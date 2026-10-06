package com.artjiang.helix.ring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class R1FrameTest {
    private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }
    private fun long(code: Int) = bytes(0x00, 0x09, 0x61, 0x00, code, 0x00, 0x00, 0x10, 0x20, 0x30, 0x40)

    @Test
    fun `short frames decode`() {
        assertEquals(R1Gesture.TAP, R1Frame.decode(bytes(0xFF, 0x04, 0x01)))
        assertEquals(R1Gesture.DOUBLE_TAP, R1Frame.decode(bytes(0xFF, 0x04, 0x02)))
        assertEquals(R1Gesture.HOLD, R1Frame.decode(bytes(0xFF, 0x03, 0x20)))
        assertEquals(R1Gesture.SWIPE_FORWARD, R1Frame.decode(bytes(0xFF, 0x05, 0x01)))
        assertEquals(R1Gesture.SWIPE_FORWARD, R1Frame.decode(bytes(0xFF, 0x05, 0x00)))
        assertEquals(R1Gesture.SWIPE_BACK, R1Frame.decode(bytes(0xFF, 0x05, 0x02)))
    }

    @Test
    fun `long frames decode`() {
        assertEquals(R1Gesture.HOLD, R1Frame.decode(long(0x00)))
        assertEquals(R1Gesture.TAP, R1Frame.decode(long(0x01)))
        assertEquals(R1Gesture.DOUBLE_TAP, R1Frame.decode(long(0x02)))
        assertEquals(R1Gesture.SWIPE_BACK, R1Frame.decode(long(0x04)))
        assertEquals(R1Gesture.SWIPE_FORWARD, R1Frame.decode(long(0x05)))
        assertEquals(R1Gesture.HOLD_RELEASE, R1Frame.decode(long(0x08)))
    }

    @Test
    fun `unknown and malformed frames are ignored`() {
        assertNull(R1Frame.decode(null))
        assertNull(R1Frame.decode(ByteArray(0)))
        assertNull(R1Frame.decode(bytes(0xFF, 0x04)))
        assertNull(R1Frame.decode(bytes(0xFF, 0x04, 0x07)))
        assertNull(R1Frame.decode(bytes(0xFE, 0x04, 0x01)))
        assertNull(R1Frame.decode(long(0x03)))
        assertNull(R1Frame.decode(bytes(0x01, 0x09, 0x61, 0x00, 0x01, 0, 0, 0, 0, 0, 0)))
        assertNull(R1Frame.decode(ByteArray(15)))
    }

    @Test
    fun `same gesture inside window counts once`() {
        var now = 0L
        val d = R1GestureDeduper(clock = { now })
        assertTrue(d.accept(R1Gesture.TAP))
        now = 100
        assertFalse(d.accept(R1Gesture.TAP))
        assertTrue(d.accept(R1Gesture.SWIPE_FORWARD))
        now = 300
        assertTrue(d.accept(R1Gesture.SWIPE_FORWARD))
    }

    @Test
    fun `ring names match only R1 adverts`() {
        assertTrue(R1Frame.isRingName("EVEN R1_A1B2C3"))
        assertFalse(R1Frame.isRingName("Even G1_42_L_ABC"))
        assertFalse(R1Frame.isRingName(null))
    }

    @Test
    fun `only a bonded ring is ever chosen`() {
        val spoofed = RingCandidate(name = "EVEN R1_AAAAAA", bonded = false)
        val glasses = RingCandidate(name = "Even G1_42_L_ABC", bonded = true)
        val mine = RingCandidate(name = "EVEN R1_B1B2B3", bonded = true)
        assertNull(R1Frame.pickRing(listOf(spoofed, glasses)))
        assertEquals(mine, R1Frame.pickRing(listOf(spoofed, glasses, mine)))
    }
}
