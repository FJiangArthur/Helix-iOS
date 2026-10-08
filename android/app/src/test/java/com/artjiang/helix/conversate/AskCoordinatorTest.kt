package com.artjiang.helix.conversate

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AskCoordinatorTest {
    private class Rig(scope: TestScope) {
        var live = false
        val shown = mutableListOf<Pair<CueType, String>>()
        val asked = mutableListOf<Triple<String, String?, Boolean>>()
        var gate: CompletableDeferred<Unit>? = null
        var reply: (String, (String) -> Unit) -> String = { _, onDelta -> onDelta("Can"); onDelta("berra."); "Canberra." }
        val coordinator = AskCoordinator(
            scope = scope.backgroundScope,
            ask = { q, ctx, deep, onDelta ->
                asked += Triple(q, ctx, deep)
                gate?.await()
                reply(q, onDelta)
            },
            show = { type, text -> shown += type to text },
        )
    }

    @Test
    fun `idle answer streams to the phone and lands as an answer card`() = runTest {
        val rig = Rig(this)
        rig.coordinator.ask("Capital of Australia?", context = "travel", deep = true)
        runCurrent()
        assertEquals(Triple("Capital of Australia?", "travel", true), rig.asked.single())
        val state = rig.coordinator.state.value
        assertEquals("Canberra.", state.answer)
        assertFalse(state.streaming)
        assertNull(state.error)
        assertEquals(listOf(CueType.ANSWER to "Canberra."), rig.shown)
    }

    @Test
    fun `phone sees partial text while streaming`() = runTest {
        val rig = Rig(this)
        rig.gate = CompletableDeferred()
        rig.coordinator.ask("q", null, false)
        runCurrent()
        assertTrue(rig.coordinator.state.value.streaming)
        assertEquals("q", rig.coordinator.state.value.question)
        rig.gate!!.complete(Unit)
        runCurrent()
        assertEquals("Canberra.", rig.coordinator.state.value.answer)
    }

    @Test
    fun `a new question cancels the running one`() = runTest {
        val rig = Rig(this)
        rig.gate = CompletableDeferred()
        rig.coordinator.ask("first", null, false)
        runCurrent()
        rig.gate = null
        rig.reply = { q, _ -> "answer to $q" }
        rig.coordinator.ask("second", null, false)
        runCurrent()
        assertEquals(listOf(CueType.ANSWER to "answer to second"), rig.shown)
        assertEquals("second", rig.coordinator.state.value.question)
    }

    @Test
    fun `relay unreachable becomes a notice`() = runTest {
        val rig = Rig(this)
        rig.live = true
        rig.reply = { _, _ -> throw RelayException(RelayException.Kind.UNREACHABLE, "x") }
        rig.coordinator.ask("q", null, false)
        runCurrent()
        assertEquals(listOf(CueType.NOTICE to "Ask failed: relay unreachable"), rig.shown)
        assertEquals("Ask failed: relay unreachable", rig.coordinator.state.value.error)
        assertFalse(rig.coordinator.state.value.streaming)
    }

    @Test
    fun `blank question is ignored`() = runTest {
        val rig = Rig(this)
        rig.coordinator.ask("   ", null, false)
        runCurrent()
        assertTrue(rig.asked.isEmpty())
    }
}
