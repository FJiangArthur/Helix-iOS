package com.artjiang.helix

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HudAnswerBatchPolicyTest {

    @Test
    fun `two ordered answers use one HUD lifecycle and no card claims sole ACK ownership`() {
        val calls = mutableListOf<HudAnswerPresentation>()
        presentHudAnswerBatch(
            listOf(
                HudAnsweredTurn("What is RAG?", "Retrieval-augmented generation.", 41L),
                HudAnsweredTurn("How does it help?", "It grounds the answer.", 42L),
            ),
        ) { calls += it }

        assertEquals("one batch means one G1 presentation and one ACK delivery id", 1, calls.size)
        assertNull("a combined ACK must not be attributed to only one answer card", calls.single().ownerFeedEntryId)
        assertEquals(setOf(41L, 42L), calls.single().answerFeedEntryIds)
        assertTrue(calls.single().text.contains("What is RAG?"))
        assertTrue(calls.single().text.contains("How does it help?"))
    }

    @Test
    fun `single answer preserves its feed entry as ACK owner`() {
        val presentation = hudAnswerPresentation(
            listOf(HudAnsweredTurn("Question?", "Answer.", 9L)),
        )!!

        assertEquals("Answer.", presentation.text)
        assertEquals(9L, presentation.ownerFeedEntryId)
        assertEquals(setOf(9L), presentation.answerFeedEntryIds)
    }
}
