// Multi-tap burst detection for the G1 touchpad.
//
// The firmware emits no triple-tap event — the official EvenDemoApp's handler
// (lib/ble_manager.dart:154-175) sees only notify indices 0/1/23/24 — so a
// triple tap is three index-1 frames that must be grouped by timing here.
package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class G1TapCounterTest {

    private class FakeClock(var now: Long = 0) : () -> Long {
        override fun invoke(): Long = now
    }

    private fun counter(clock: FakeClock, window: Long = 400) =
        G1TapCounter(multiTapWindowMillis = window, clock = clock)

    @Test
    fun threeQuickTapsReportAsOneTripleBurst() {
        val clock = FakeClock()
        val c = counter(clock)

        assertNull(c.onTap(G1TouchpadSide.RIGHT))
        clock.now = 120
        assertNull(c.onTap(G1TouchpadSide.RIGHT))
        clock.now = 240
        assertNull(c.onTap(G1TouchpadSide.RIGHT))

        // Still inside the window: nothing reported yet.
        clock.now = 500
        assertNull("the burst must not fire before the window closes", c.pollExpired())

        clock.now = 641
        assertEquals(G1TapCounter.Burst(3, G1TouchpadSide.RIGHT), c.pollExpired())
    }

    @Test
    fun aLoneTapReportsAsASingle() {
        val clock = FakeClock()
        val c = counter(clock)

        c.onTap(G1TouchpadSide.RIGHT)
        clock.now = 401

        assertEquals(G1TapCounter.Burst(1, G1TouchpadSide.RIGHT), c.pollExpired())
    }

    @Test
    fun tapsSpacedBeyondTheWindowAreSeparateSingles() {
        val clock = FakeClock()
        val c = counter(clock)

        c.onTap(G1TouchpadSide.RIGHT)
        clock.now = 401
        // The next tap arrives after the window: it must flush the first as a
        // single rather than merge into a double.
        assertEquals(G1TapCounter.Burst(1, G1TouchpadSide.RIGHT), c.onTap(G1TouchpadSide.RIGHT))

        clock.now = 802
        assertEquals(G1TapCounter.Burst(1, G1TouchpadSide.RIGHT), c.pollExpired())
    }

    @Test
    fun switchingPadsFlushesTheBurstInProgress() {
        val clock = FakeClock()
        val c = counter(clock)

        c.onTap(G1TouchpadSide.RIGHT)
        clock.now = 100
        c.onTap(G1TouchpadSide.RIGHT)
        clock.now = 200

        // A left tap mid-burst must report the two right taps, not discard them.
        assertEquals(G1TapCounter.Burst(2, G1TouchpadSide.RIGHT), c.onTap(G1TouchpadSide.LEFT))

        clock.now = 601
        assertEquals(G1TapCounter.Burst(1, G1TouchpadSide.LEFT), c.pollExpired())
    }

    @Test
    fun millisUntilExpiryDrivesTheTrailingWake() {
        val clock = FakeClock()
        val c = counter(clock)

        assertNull("idle counter has nothing to wake for", c.millisUntilExpiry())

        c.onTap(G1TouchpadSide.RIGHT)
        assertEquals(400L, c.millisUntilExpiry())

        clock.now = 150
        assertEquals(250L, c.millisUntilExpiry())

        clock.now = 900
        assertEquals("an overdue burst waits zero, never negative", 0L, c.millisUntilExpiry())
    }

    @Test
    fun resetDropsAPendingBurst() {
        val clock = FakeClock()
        val c = counter(clock)

        c.onTap(G1TouchpadSide.RIGHT)
        c.reset()
        clock.now = 1_000

        assertNull(c.pollExpired())
    }
}
