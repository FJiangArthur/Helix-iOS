package com.artjiang.helix.conversate

import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class ReminderSchedulerTest {
    private class Rig(scope: TestScope) {
        val sinces = mutableListOf<Long>()
        val delivered = mutableListOf<String>()
        var responses: MutableList<() -> List<RelayReminder>> = mutableListOf()
        var configured = true
        val scheduler = ReminderScheduler(
            scope = scope.backgroundScope,
            fetch = { since ->
                sinces += since
                (responses.removeFirstOrNull() ?: { emptyList() })()
            },
            deliver = { delivered += it.id },
            clock = { scope.testScheduler.currentTime + START },
            isConfigured = { configured },
        )
    }

    private fun r(id: String) = RelayReminder(id, "todo", "text $id")

    @Test
    fun `polls at start and every five minutes`() = runTest {
        val rig = Rig(this)
        rig.scheduler.start()
        runCurrent()
        assertEquals(1, rig.sinces.size)
        advanceTimeBy(5 * 60_000L - 1); runCurrent()
        assertEquals(1, rig.sinces.size)
        advanceTimeBy(1); runCurrent()
        assertEquals(2, rig.sinces.size)
        advanceTimeBy(10 * 60_000L); runCurrent()
        assertEquals(4, rig.sinces.size)
    }

    @Test
    fun `since starts one interval back and then follows the last good poll`() = runTest {
        val rig = Rig(this)
        rig.scheduler.start(); runCurrent()
        advanceTimeBy(5 * 60_000L); runCurrent()
        assertEquals(listOf(START - 5 * 60_000L, START), rig.sinces)
    }

    @Test
    fun `each reminder id is delivered once`() = runTest {
        val rig = Rig(this)
        rig.responses = mutableListOf({ listOf(r("a"), r("b")) }, { listOf(r("b"), r("c")) })
        rig.scheduler.start(); runCurrent()
        advanceTimeBy(5 * 60_000L); runCurrent()
        assertEquals(listOf("a", "b", "c"), rig.delivered)
    }

    @Test
    fun `a failed poll keeps the loop and the since mark`() = runTest {
        val rig = Rig(this)
        rig.responses = mutableListOf({ throw RelayException(RelayException.Kind.UNREACHABLE, "down") }, { listOf(r("a")) })
        rig.scheduler.start(); runCurrent()
        advanceTimeBy(5 * 60_000L); runCurrent()
        assertEquals(listOf("a"), rig.delivered)
        assertEquals(listOf(START - 5 * 60_000L, START - 5 * 60_000L), rig.sinces)
    }

    @Test
    fun `unconfigured relay is never polled and stop ends polling`() = runTest {
        val rig = Rig(this)
        rig.configured = false
        rig.scheduler.start(); runCurrent()
        assertEquals(0, rig.sinces.size)
        rig.configured = true
        advanceTimeBy(5 * 60_000L); runCurrent()
        assertEquals(1, rig.sinces.size)
        rig.scheduler.stop()
        advanceTimeBy(30 * 60_000L); runCurrent()
        assertEquals(1, rig.sinces.size)
    }

    private companion object {
        const val START = 1_700_000_000_000L
    }
}
