package com.artjiang.helix

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HudArbiterTest {

    /** Test clock so expiry is exercised without real waiting. */
    private class FakeClock(var now: Long = 0) : () -> Long {
        override fun invoke(): Long = now
    }

    @Test
    fun `first request always wins`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
    }

    @Test
    fun `higher priority preempts an unexpired holder`() = runTest {
        val clock = FakeClock()
        val arbiter = HudArbiter(clock)
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
        assertEquals(HudArbiter.Priority.ANSWER, arbiter.currentHolder())
    }

    @Test
    fun `lower priority is refused while a holder is live`() = runTest {
        val clock = FakeClock()
        val arbiter = HudArbiter(clock)
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
        clock.now += 1_000
        assertFalse(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
        assertEquals(HudArbiter.Priority.ANSWER, arbiter.currentHolder())
    }

    @Test
    fun `equal priority always re-grants`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
    }

    @Test
    fun `lower priority wins once the holder's window expires`() = runTest {
        val clock = FakeClock()
        val arbiter = HudArbiter(clock)
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
        // Answers hold for 30 s; an insight must wait that out.
        clock.now += HudArbiter.ANSWER_DURATION_MILLIS - 1
        assertFalse(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
        clock.now += 1
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
    }

    @Test
    fun `an answer cannot hold the HUD forever`() = runTest {
        val clock = FakeClock()
        val arbiter = HudArbiter(clock)
        arbiter.requestDisplay(HudArbiter.Priority.ANSWER)
        clock.now += HudArbiter.ANSWER_DURATION_MILLIS + 1
        assertNull(arbiter.currentHolder())
    }

    @Test
    fun `release frees the display immediately`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        arbiter.requestDisplay(HudArbiter.Priority.ANSWER)
        arbiter.releaseDisplay()
        assertNull(arbiter.currentHolder())
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
    }

    @Test
    fun `explicit duration overrides the per-priority default`() = runTest {
        val clock = FakeClock()
        val arbiter = HudArbiter(clock)
        arbiter.requestDisplay(HudArbiter.Priority.ANSWER, durationMillis = 500)
        clock.now += 501
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.INSIGHT))
    }

    @Test
    fun `default durations match the documented windows`() {
        assertEquals(30_000L, HudArbiter.defaultDurationFor(HudArbiter.Priority.ANSWER))
        assertEquals(10_000L, HudArbiter.defaultDurationFor(HudArbiter.Priority.INSIGHT))
        assertEquals(10_000L, HudArbiter.defaultDurationFor(HudArbiter.Priority.NOTIFICATION))
    }
}
