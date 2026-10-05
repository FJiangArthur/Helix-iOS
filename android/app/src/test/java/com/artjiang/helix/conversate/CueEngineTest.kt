package com.artjiang.helix.conversate

import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CueEngineTest {
    private class Rig(scope: TestScope, var reply: () -> String) {
        val emitted = mutableListOf<Cue>()
        val prompts = mutableListOf<String>()
        val engine = CueEngine(
            scope = scope.backgroundScope,
            classify = { p, _ -> prompts += p; reply() },
            prompt = CuePrompt(1, 600, "S={{shown}} P={{prep_note}} T={{transcript}}"),
            clock = { scope.testScheduler.currentTime },
            emit = { emitted += it },
        )
    }
    private fun json(vararg titles: String) =
        """{"cues":[${titles.joinToString(",") { """{"type":"CONCEPT","title":"$it","body":"b $it","entity":"$it"}""" }}]}"""

    @Test
    fun `debounces finals into one call`() = runTest {
        val rig = Rig(this) { json("RAG") }
        rig.engine.onFinal("We use"); advanceTimeBy(500)
        rig.engine.onFinal("RAG here."); advanceTimeBy(1_600)
        assertEquals(1, rig.prompts.size)
        assertTrue(rig.prompts[0].contains("We use RAG here."))
        assertEquals(listOf("RAG"), rig.emitted.map { it.title })
    }

    @Test
    fun `at most one cue per gap and no repeats`() = runTest {
        val rig = Rig(this) { json("RAG", "API") }
        rig.engine.onFinal("a"); advanceTimeBy(1_600)
        assertEquals(listOf("RAG"), rig.emitted.map { it.title })
        rig.engine.onFinal("b"); advanceTimeBy(1_600)
        assertEquals(1, rig.emitted.size)
        advanceTimeBy(8_000); rig.engine.onFinal("c"); advanceTimeBy(1_600)
        assertEquals(listOf("RAG", "API"), rig.emitted.map { it.title })
        assertTrue(rig.prompts.last().contains("S=RAG"))
    }

    @Test
    fun `failures are counted and reset on success`() = runTest {
        var fail = true
        val rig = Rig(this) { if (fail) error("boom") else json("X") }
        repeat(3) { rig.engine.onFinal("t$it"); advanceTimeBy(1_600) }
        assertEquals(3, rig.engine.failures.value)
        fail = false
        rig.engine.onFinal("ok"); advanceTimeBy(1_600)
        assertEquals(0, rig.engine.failures.value)
    }

    @Test
    fun `a new final does not cancel the call in flight`() = runTest {
        var calls = 0
        val rig = Rig(this) { calls++; json("RAG") }
        val slow = CueEngine(
            scope = backgroundScope,
            classify = { _, _ -> calls++; kotlinx.coroutines.delay(3_000); json("RAG") },
            prompt = CuePrompt(1, 600, "{{transcript}}"),
            clock = { testScheduler.currentTime },
            emit = { rig.emitted += it },
        )
        slow.onFinal("a"); advanceTimeBy(1_600)
        slow.onFinal("b"); advanceTimeBy(1_600)
        advanceTimeBy(2_000)
        assertEquals(listOf("RAG"), rig.emitted.map { it.title })
        assertEquals(0, slow.failures.value)
    }

    @Test
    fun `malformed output emits nothing`() = runTest {
        val rig = Rig(this) { "no json" }
        rig.engine.onFinal("x"); advanceTimeBy(1_600)
        assertEquals(0, rig.emitted.size)
    }

    @Test
    fun `transcript window drops old text and prep note is included`() = runTest {
        val rig = Rig(this) { json() }
        rig.engine.setPrepNote("Acme deal")
        rig.engine.onFinal("old"); advanceTimeBy(61_000)
        rig.engine.onFinal("new"); advanceTimeBy(1_600)
        assertTrue(rig.prompts.last().contains("T=new"))
        assertTrue(rig.prompts.last().contains("P=Acme deal"))
    }
}
