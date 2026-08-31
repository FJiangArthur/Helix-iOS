package com.artjiang.helix.knowledge

import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import com.artjiang.helix.core.SessionSummary
import com.artjiang.helix.data.KnowledgeRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The projection from stored app data (KnowledgeItems + SessionSummaries) into
 * the builder's flat turn list. Pure function — no Android, no file I/O.
 */
class ConversationTurnsTest {

    private fun item(id: String, text: String) = KnowledgeItem(
        id = id,
        bucket = KnowledgeBucket.FACTS,
        text = text,
        source = "Manual",
        createdAtMillis = 0L,
    )

    private fun session(id: String, title: String, turns: List<String>, answer: String) =
        SessionSummary(
            id = id,
            title = title,
            answerPreview = answer,
            transcriptTurns = turns,
            answerCount = 1,
            createdAtMillis = 0L,
        )

    @Test
    fun `empty inputs produce no turns`() {
        assertTrue(KnowledgeRepository.conversationTurns(emptyList(), emptyList()).isEmpty())
    }

    @Test
    fun `knowledge items become KNOWLEDGE turns with prefixed ids`() {
        val turns = KnowledgeRepository.conversationTurns(
            listOf(item("abc", "the glasses use dual BLE")),
            emptyList(),
        )
        assertEquals(1, turns.size)
        assertEquals("k:abc", turns[0].id)
        assertEquals(NodeKind.KNOWLEDGE, turns[0].kind)
        assertEquals("the glasses use dual BLE", turns[0].text)
    }

    @Test
    fun `session transcript lines and answer are tagged with the session`() {
        val turns = KnowledgeRepository.conversationTurns(
            emptyList(),
            listOf(session("s1", "Standup", listOf("first line", "second line"), "the answer")),
        )
        assertEquals(3, turns.size)
        assertTrue(turns.all { it.sessionId == "s:s1" })
        assertTrue(turns.all { it.sessionLabel == "Standup" })
        assertEquals(NodeKind.ANSWER, turns.last().kind)
        assertEquals(2, turns.count { it.kind == NodeKind.QUESTION })
    }

    @Test
    fun `blank transcript lines and blank answers are skipped`() {
        val turns = KnowledgeRepository.conversationTurns(
            emptyList(),
            listOf(session("s1", "Empty", listOf("real line", "   ", ""), "")),
        )
        assertEquals(1, turns.size)
        assertEquals("real line", turns[0].text)
    }

    @Test
    fun `turn ids are unique across sessions and knowledge`() {
        val turns = KnowledgeRepository.conversationTurns(
            listOf(item("a", "one"), item("b", "two")),
            listOf(
                session("s1", "A", listOf("x", "y"), "ans"),
                session("s2", "B", listOf("z"), "ans2"),
            ),
        )
        assertEquals(turns.size, turns.map { it.id }.distinct().size)
    }

    @Test
    fun `projection is deterministic regardless of input order`() {
        val items = listOf(item("b", "two"), item("a", "one"))
        val sessions = listOf(session("s2", "B", listOf("z"), "q"), session("s1", "A", listOf("x"), "p"))
        val forward = KnowledgeRepository.conversationTurns(items, sessions)
        val reversed = KnowledgeRepository.conversationTurns(items.reversed(), sessions.reversed())
        assertEquals(forward, reversed)
    }

    @Test
    fun `projected turns feed the builder end to end`() {
        val turns = KnowledgeRepository.conversationTurns(
            listOf(item("k1", "the deployment pipeline uses Even Realities glasses")),
            listOf(session("s1", "Standup", listOf("deployment pipeline is green"), "deployment finished")),
        )
        val graph = KnowledgeGraphBuilder().build(turns)
        assertTrue("expected topic nodes", graph.nodes.any { it.label == "deployment" })
        assertTrue("expected a session node", graph.nodes.any { it.kind == NodeKind.SESSION })
        assertTrue("expected edges", graph.edges.isNotEmpty())
    }
}
