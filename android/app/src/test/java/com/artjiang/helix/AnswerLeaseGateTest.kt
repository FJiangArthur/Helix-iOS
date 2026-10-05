package com.artjiang.helix

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnswerLeaseGateTest {
    @Test
    fun `a notice from the same session cannot ride the answer lease`() = runTest {
        val arbiter = HudArbiter { 0L }
        val gate = AnswerLeaseGate(arbiter)
        assertTrue(gate.request(HudArbiter.Priority.ANSWER))
        assertFalse(gate.request(HudArbiter.Priority.NOTIFICATION))
    }

    @Test
    fun `answer pages may re-request their own lease`() = runTest {
        val arbiter = HudArbiter { 0L }
        val gate = AnswerLeaseGate(arbiter)
        assertTrue(gate.request(HudArbiter.Priority.ANSWER))
        assertTrue(gate.request(HudArbiter.Priority.ANSWER))
        assertTrue(gate.owns())
    }

    @Test
    fun `ownership is lost once another producer takes the hud`() = runTest {
        val arbiter = HudArbiter { 0L }
        val gate = AnswerLeaseGate(arbiter)
        gate.request(HudArbiter.Priority.ANSWER)
        arbiter.acquire(HudArbiter.Priority.CONVERSATE_INTERACTIVE)
        assertFalse(gate.owns())
    }

    @Test
    fun `an expired but unsuperseded lease is still ours to clear`() = runTest {
        var now = 0L
        val arbiter = HudArbiter { now }
        val gate = AnswerLeaseGate(arbiter)
        gate.request(HudArbiter.Priority.ANSWER)
        now += HudArbiter.ANSWER_DURATION_MILLIS + 1
        assertTrue(gate.owns())
        gate.release()
        assertFalse(gate.owns())
    }
}
