package com.artjiang.helix.knowledge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Graph construction: entity/topic extraction, stopword filtering, the
 * frequency floor, co-occurrence weights, and byte-level determinism.
 */
class KnowledgeGraphBuilderTest {

    private fun turn(id: String, text: String, kind: NodeKind = NodeKind.QUESTION) =
        ConversationTurn(id = id, text = text, kind = kind)

    private fun labels(graph: KnowledgeGraph, kind: NodeKind) =
        graph.nodes.filter { it.kind == kind }.map { it.label }

    @Test
    fun `empty input produces an empty graph`() {
        val graph = KnowledgeGraphBuilder().build(emptyList())
        assertTrue(graph.isEmpty)
        assertTrue(graph.edges.isEmpty())
    }

    @Test
    fun `repeated term becomes a topic node with its frequency as weight`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "the deployment pipeline broke"),
                turn("q2", "deployment is stuck again"),
                turn("q3", "check the deployment logs"),
            ),
        )
        val deployment = graph.nodes.single { it.label == "deployment" }
        assertEquals(NodeKind.TOPIC, deployment.kind)
        assertEquals(3, deployment.weight)
    }

    @Test
    fun `stopwords never become nodes`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "the and for with that this have from they know"),
                turn("q2", "the and for with that this have from they know"),
                turn("q3", "the and for with that this have from they know"),
            ),
        )
        val termLabels = graph.nodes.map { it.label }.toSet()
        for (stop in listOf("the", "and", "for", "with", "that", "this", "have", "from")) {
            assertFalse("stopword '$stop' leaked into the graph", stop in termLabels)
        }
    }

    @Test
    fun `frequency floor keeps one-off chatter out`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "database migration failed"),
                turn("q2", "database migration retried"),
                turn("q3", "unrelated tangent about kayaking"),
            ),
        )
        val termLabels = graph.nodes.filter { it.kind == NodeKind.TOPIC }.map { it.label }
        assertTrue("database" in termLabels)
        assertTrue("migration" in termLabels)
        // Seen once only, below the default floor of 2.
        assertFalse("kayaking" in termLabels)
    }

    @Test
    fun `capitalised multiword phrase becomes a single entity node`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(turn("q1", "we shipped the Even Realities integration")),
        )
        val entities = labels(graph, NodeKind.ENTITY)
        assertTrue("expected 'Even Realities' in $entities", "Even Realities" in entities)
        // It must NOT also be split into two lowercase topics.
        val topics = labels(graph, NodeKind.TOPIC)
        assertFalse("even" in topics)
        assertFalse("realities" in topics)
    }

    @Test
    fun `entities are admitted at a lower frequency floor than topics`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(turn("q1", "ask Marcus Webb about the rollout")),
        )
        // Entity: seen once, admitted (minEntityFrequency = 1).
        assertTrue("Marcus Webb" in labels(graph, NodeKind.ENTITY))
        // Topic: seen once, rejected (minTermFrequency = 2).
        assertFalse("rollout" in labels(graph, NodeKind.TOPIC))
    }

    @Test
    fun `sentence-initial capitalised word alone is not an entity`() {
        // Two turns because term frequency is counted per turn, not per
        // occurrence — the topic floor needs it seen in 2 distinct turns.
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "Latency spiked overnight."),
                turn("q2", "Latency spiked again."),
            ),
        )
        // "Latency" starts both sentences and has no capitalised neighbour, so
        // it must fall through to the topic path, not become a proper name.
        assertFalse("Latency" in labels(graph, NodeKind.ENTITY))
        assertTrue("latency" in labels(graph, NodeKind.TOPIC))
    }

    @Test
    fun `plural and singular fold to one node`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "the meetings ran long"),
                turn("q2", "another meeting ran long"),
            ),
        )
        val meeting = graph.nodes.filter { it.label.startsWith("meeting") }
        assertEquals("expected one folded node, got $meeting", 1, meeting.size)
        assertEquals(2, meeting.single().weight)
    }

    @Test
    fun `co-occurrence in the same turn creates an edge`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "database migration failed"),
                turn("q2", "database migration failed"),
            ),
        )
        val edge = graph.edges.single {
            it.relation == RelationKind.CO_OCCURS &&
                setOf(it.source, it.target) == setOf("t:database", "t:migration")
        }
        assertEquals(2, edge.weight)
    }

    @Test
    fun `repeated co-occurrence raises edge weight`() {
        val once = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "alpha beta"),
                turn("q2", "alpha beta"),
            ),
        )
        val thrice = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "alpha beta"),
                turn("q2", "alpha beta"),
                turn("q3", "alpha beta"),
                turn("q4", "alpha beta"),
            ),
        )
        val w1 = once.edges.single { it.relation == RelationKind.CO_OCCURS }.weight
        val w2 = thrice.edges.single { it.relation == RelationKind.CO_OCCURS }.weight
        assertTrue("weight should grow with repetition: $w1 -> $w2", w2 > w1)
    }

    @Test
    fun `terms in different turns do not co-occur`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "alpha alpha"),
                turn("q2", "alpha"),
                turn("q3", "beta beta"),
                turn("q4", "beta"),
            ),
        )
        val cross = graph.edges.filter {
            it.relation == RelationKind.CO_OCCURS &&
                setOf(it.source, it.target) == setOf("t:alpha", "t:beta")
        }
        assertTrue("alpha and beta never shared a turn: $cross", cross.isEmpty())
    }

    @Test
    fun `document nodes link to the terms they mention`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "database migration failed"),
                turn("q2", "database migration failed"),
            ),
        )
        val mentions = graph.edges.filter { it.relation == RelationKind.MENTIONS && it.source == "q1" }
        assertEquals(setOf("t:database", "t:migration", "t:failed"), mentions.map { it.target }.toSet())
        assertEquals(NodeKind.QUESTION, graph.node("q1")?.kind)
    }

    @Test
    fun `answer links to its question and both link to the session`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                ConversationTurn("q1", "database migration status", NodeKind.QUESTION, "s1", "Standup"),
                ConversationTurn("a1", "database migration completed", NodeKind.ANSWER, "s1", "Standup", answersId = "q1"),
            ),
        )
        assertNotNull(graph.edges.singleOrNull { it.relation == RelationKind.ANSWERS && it.source == "a1" && it.target == "q1" })
        val contains = graph.edges.filter { it.relation == RelationKind.CONTAINS && it.source == "s1" }
        assertEquals(setOf("q1", "a1"), contains.map { it.target }.toSet())
        assertEquals(NodeKind.SESSION, graph.node("s1")?.kind)
    }

    @Test
    fun `edges never reference a node that was cut by the cap`() {
        val turns = (0 until 40).map { i -> turn("q$i", "term$i term$i shared shared") }
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(maxTermNodes = 5)).build(turns)
        val ids = graph.nodes.map { it.id }.toSet()
        for (edge in graph.edges) {
            assertTrue("dangling source ${edge.source}", edge.source in ids)
            assertTrue("dangling target ${edge.target}", edge.target in ids)
        }
    }

    @Test
    fun `output is deterministic across repeated builds`() {
        val turns = listOf(
            ConversationTurn("q1", "The Helix roadmap covers glasses and transcription", NodeKind.QUESTION, "s1", "Planning"),
            ConversationTurn("a1", "Helix ships glasses transcription in the next roadmap", NodeKind.ANSWER, "s1", "Planning", answersId = "q1"),
            ConversationTurn("k1", "Even Realities glasses use dual BLE", NodeKind.KNOWLEDGE),
            ConversationTurn("q2", "how does transcription handle glasses audio", NodeKind.QUESTION, "s2", "Debug"),
        )
        val first = KnowledgeGraphBuilder().build(turns)
        repeat(20) {
            val again = KnowledgeGraphBuilder().build(turns)
            assertEquals(first.nodes, again.nodes)
            assertEquals(first.edges, again.edges)
        }
    }

    @Test
    fun `nodes are sorted by descending weight and edges by descending weight`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "alpha beta gamma"),
                turn("q2", "alpha beta"),
                turn("q3", "alpha"),
                turn("q4", "alpha"),
            ),
        )
        val weights = graph.nodes.map { it.weight }
        assertEquals(weights.sortedDescending(), weights)
        val edgeWeights = graph.edges.map { it.weight }
        assertEquals(edgeWeights.sortedDescending(), edgeWeights)
    }

    @Test
    fun `co-occurrence edge is stored canonically regardless of word order`() {
        val forward = KnowledgeGraphBuilder().build(
            listOf(turn("q1", "alpha beta"), turn("q2", "alpha beta")),
        )
        val reversed = KnowledgeGraphBuilder().build(
            listOf(turn("q1", "beta alpha"), turn("q2", "beta alpha")),
        )
        val f = forward.edges.single { it.relation == RelationKind.CO_OCCURS }
        val r = reversed.edges.single { it.relation == RelationKind.CO_OCCURS }
        assertEquals(f.source, r.source)
        assertEquals(f.target, r.target)
        assertEquals(f.weight, r.weight)
    }

    @Test
    fun `neighbors of a node are reachable for detail drilldown`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "database migration failed"),
                turn("q2", "database migration failed"),
            ),
        )
        val neighbors = graph.neighborsOf("t:database").map { it.id }
        assertTrue("t:migration" in neighbors)
        assertTrue("q1" in neighbors)
        assertNull(graph.node("t:nonexistent"))
    }

    @Test
    fun `CJK text produces bigram nodes rather than nothing`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "会议记录很重要"),
                turn("q2", "会议记录已经保存"),
            ),
        )
        assertTrue("expected CJK bigram nodes", graph.nodes.any { it.label == "会议" })
    }

    @Test
    fun `numeric-only tokens are ignored`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(turn("q1", "2026 2026 budget budget"), turn("q2", "2026 budget")),
        )
        assertFalse("2026" in graph.nodes.map { it.label })
        assertTrue("budget" in graph.nodes.map { it.label })
    }

    @Test
    fun `document nodes can be disabled`() {
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(includeDocumentNodes = false)).build(
            listOf(turn("q1", "alpha beta"), turn("q2", "alpha beta")),
        )
        assertTrue(graph.nodes.none { it.kind == NodeKind.QUESTION })
        assertTrue(graph.edges.none { it.relation == RelationKind.MENTIONS })
    }

    @Test
    fun `huge turn does not explode into quadratic edges`() {
        val manyTerms = (0 until 100).joinToString(" ") { "term$it" }
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(maxTermsPerTurn = 5))
            .build(listOf(turn("q1", manyTerms), turn("q2", manyTerms)))
        val coOccurs = graph.edges.count { it.relation == RelationKind.CO_OCCURS }
        // 5 terms -> at most 10 pairs.
        assertTrue("expected <= 10 co-occurrence edges, got $coOccurs", coOccurs <= 10)
    }

    @Test
    fun `document nodes are capped so a long history stays readable`() {
        val turns = (0 until 500).map { i ->
            turn("q$i", "deployment pipeline latency budget stage$i")
        }
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(maxDocumentNodes = 25)).build(turns)
        val documents = graph.nodes.count {
            it.kind == NodeKind.QUESTION || it.kind == NodeKind.ANSWER || it.kind == NodeKind.KNOWLEDGE
        }
        assertTrue("expected <= 25 document nodes, got $documents", documents <= 25)
        // And the whole graph stays bounded overall.
        assertTrue("graph too large: ${graph.nodes.size}", graph.nodes.size <= 25 + 60 + 1)
    }

    @Test
    fun `no dangling edges survive the document cap`() {
        val turns = (0 until 200).map { i ->
            ConversationTurn(
                id = "q$i",
                text = "deployment pipeline latency stage$i",
                kind = if (i % 2 == 0) NodeKind.QUESTION else NodeKind.ANSWER,
                sessionId = "s${i % 4}",
                sessionLabel = "Session ${i % 4}",
                answersId = if (i % 2 == 1) "q${i - 1}" else null,
            )
        }
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(maxDocumentNodes = 10)).build(turns)
        val ids = graph.nodes.map { it.id }.toSet()
        for (edge in graph.edges) {
            assertTrue("dangling source ${edge.source}", edge.source in ids)
            assertTrue("dangling target ${edge.target}", edge.target in ids)
        }
    }

    @Test
    fun `document cap keeps the richest documents`() {
        val turns = listOf(
            turn("rich", "deployment pipeline latency budget"),
            turn("poor", "deployment"),
            turn("filler1", "deployment pipeline latency budget"),
            turn("filler2", "deployment pipeline latency budget"),
        )
        val graph = KnowledgeGraphBuilder(GraphBuildConfig(maxDocumentNodes = 1)).build(turns)
        val documents = graph.nodes.filter { it.kind == NodeKind.QUESTION }
        assertEquals(1, documents.size)
        assertTrue("cap should keep a term-rich document, kept ${documents[0].id}", documents[0].id != "poor")
    }

    @Test
    fun `node detail carries the source text for drilldown`() {
        val graph = KnowledgeGraphBuilder().build(
            listOf(
                turn("q1", "database migration failed"),
                turn("q2", "database migration failed"),
            ),
        )
        assertEquals("database migration failed", graph.node("q1")?.detail)
    }
}
