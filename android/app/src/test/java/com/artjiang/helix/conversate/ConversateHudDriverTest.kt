package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConversateHudDriverTest {
    private class Rig(scope: TestScope, sendMillis: Long = 300) {
        val sent = mutableListOf<String>()
        var clears = 0
        val arbiter = HudArbiter { scope.testScheduler.currentTime }
        val driver = ConversateHudDriver(
            scope = scope.backgroundScope,
            sendScreen = { packets ->
                delay(sendMillis)
                sent += String(packets.first().copyOfRange(9, packets.first().size))
                G1ScreenDeliveryOutcome.deliveredToBoth(packets.size)
            },
            clearScreen = { clears++ },
            arbiter = arbiter,
            clock = { scope.testScheduler.currentTime },
        )
    }

    @Test
    fun `latest state wins over a burst`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("m0"), interactive = true)
        runCurrent()
        (1..5).forEach { rig.driver.submit(HudFrame("m$it"), interactive = true) }
        advanceTimeBy(2_000)
        assertEquals(listOf("m0", "m5"), rig.sent)
    }

    @Test
    fun `identical frames are not resent`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("a"), true); advanceTimeBy(1_000)
        rig.driver.submit(HudFrame("a"), true); advanceTimeBy(1_000)
        assertEquals(listOf("a"), rig.sent)
    }

    @Test
    fun `captions are spaced by the interval, interactive is immediate`() = runTest {
        val rig = Rig(this, sendMillis = 100)
        rig.driver.submit(HudFrame("c1"), false); advanceTimeBy(150)
        rig.driver.submit(HudFrame("c2"), false); advanceTimeBy(300)
        assertEquals(listOf("c1"), rig.sent)
        advanceTimeBy(500)
        assertEquals(listOf("c1", "c2"), rig.sent)
        rig.driver.submit(HudFrame("c3"), false); advanceTimeBy(50)
        rig.driver.submit(HudFrame("menu"), true); advanceTimeBy(150)
        assertEquals(listOf("c1", "c2", "menu"), rig.sent)
    }

    @Test
    fun `driver clears after in-flight send and releases the lease`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("x"), false); runCurrent()
        rig.driver.submit(null, true)
        advanceTimeBy(1_000)
        assertEquals(listOf("x"), rig.sent)
        assertEquals(1, rig.clears)
        assertNull(rig.arbiter.currentHolder())
    }

    @Test
    fun `captions draw again after a menu closes`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("menu"), true); advanceTimeBy(1_000)
        rig.driver.submit(HudFrame("caption"), false); advanceTimeBy(1_000)
        assertEquals(listOf("menu", "caption"), rig.sent)
    }

    @Test
    fun `failed send is retried on the next identical frame`() = runTest {
        var fail = true
        val sent = mutableListOf<String>()
        val driver = ConversateHudDriver(
            scope = backgroundScope,
            sendScreen = { p ->
                if (fail) G1ScreenDeliveryOutcome.failed(p.size)
                else { sent += "ok"; G1ScreenDeliveryOutcome.deliveredToBoth(p.size) }
            },
            clearScreen = {},
            arbiter = HudArbiter { testScheduler.currentTime },
            clock = { testScheduler.currentTime },
        )
        driver.submit(HudFrame("a"), true); advanceTimeBy(500)
        fail = false
        driver.submit(HudFrame("a"), true); advanceTimeBy(500)
        assertEquals(listOf("ok"), sent)
    }

    @Test
    fun `refused lease skips the draw`() = runTest {
        val rig = Rig(this)
        rig.arbiter.acquire(HudArbiter.Priority.CONVERSATE_INTERACTIVE)
        rig.driver.submit(HudFrame("caption"), false); advanceTimeBy(1_000)
        assertEquals(emptyList<String>(), rig.sent)
    }

    @Test
    fun `shutdown clears and releases`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("x"), true); advanceTimeBy(1_000)
        rig.driver.shutdown()
        assertEquals(1, rig.clears)
        assertNull(rig.arbiter.currentHolder())
    }
}
