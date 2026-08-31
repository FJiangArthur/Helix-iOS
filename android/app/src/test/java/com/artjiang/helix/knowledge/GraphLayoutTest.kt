package com.artjiang.helix.knowledge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt

/**
 * Layout solver: determinism for a seed, finiteness (no NaN/Inf) in every
 * degenerate case, in-bounds output, convergence, and the budget cap.
 */
class GraphLayoutTest {

    private val config = LayoutConfig(width = 100f, height = 100f, budgetMillis = 0L)

    private fun node(id: String, weight: Int = 1) =
        GraphNode(id = id, label = id, kind = NodeKind.TOPIC, weight = weight)

    private fun graphOf(nodeCount: Int, edges: List<Pair<Int, Int>> = emptyList()): KnowledgeGraph {
        val nodes = (0 until nodeCount).map { node("n$it", weight = it + 1) }
        return KnowledgeGraph(
            nodes = nodes.sortedWith(compareByDescending<GraphNode> { it.weight }.thenBy { it.id }),
            edges = edges.map { (a, b) -> GraphEdge("n$a", "n$b", RelationKind.CO_OCCURS, 1) },
        )
    }

    private fun assertAllFinite(result: GraphLayoutResult) {
        for (p in result.positions) {
            assertTrue("NaN x for ${p.id}", !p.x.isNaN())
            assertTrue("NaN y for ${p.id}", !p.y.isNaN())
            assertTrue("infinite x for ${p.id}", p.x.isFinite())
            assertTrue("infinite y for ${p.id}", p.y.isFinite())
            assertTrue("NaN weight for ${p.id}", !p.normalizedWeight.isNaN())
        }
    }

    private fun assertInBounds(result: GraphLayoutResult, cfg: LayoutConfig) {
        for (p in result.positions) {
            assertTrue("${p.id} x=${p.x} out of bounds", p.x >= -0.01f && p.x <= cfg.width + 0.01f)
            assertTrue("${p.id} y=${p.y} out of bounds", p.y >= -0.01f && p.y <= cfg.height + 0.01f)
        }
    }

    @Test
    fun `zero nodes returns an empty result`() {
        val result = GraphLayout.compute(KnowledgeGraph.EMPTY, config)
        assertTrue(result.positions.isEmpty())
        assertEquals(0, result.iterations)
    }

    @Test
    fun `one node is centred and finite`() {
        val result = GraphLayout.compute(graphOf(1), config)
        assertEquals(1, result.positions.size)
        assertEquals(50f, result.positions[0].x, 0.001f)
        assertEquals(50f, result.positions[0].y, 0.001f)
        assertAllFinite(result)
    }

    @Test
    fun `two connected nodes stay finite and in bounds`() {
        val result = GraphLayout.compute(graphOf(2, listOf(0 to 1)), config)
        assertEquals(2, result.positions.size)
        assertAllFinite(result)
        assertInBounds(result, config)
    }

    @Test
    fun `two disconnected nodes do not collapse onto each other`() {
        val result = GraphLayout.compute(graphOf(2), config)
        assertAllFinite(result)
        val a = result.positions[0]
        val b = result.positions[1]
        val distance = sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
        assertTrue("nodes collapsed to the same point", distance > 1f)
    }

    @Test
    fun `same seed produces identical positions`() {
        val graph = graphOf(20, (0 until 19).map { it to it + 1 })
        val first = GraphLayout.compute(graph, config)
        repeat(10) {
            val again = GraphLayout.compute(graph, config)
            assertEquals(first.positions, again.positions)
        }
    }

    @Test
    fun `different seeds produce different layouts`() {
        val graph = graphOf(20, (0 until 19).map { it to it + 1 })
        val a = GraphLayout.compute(graph, config.copy(seed = 1L))
        val b = GraphLayout.compute(graph, config.copy(seed = 999L))
        assertNotEquals(a.positions, b.positions)
    }

    @Test
    fun `parallel path produces the same result as the serial path`() {
        val graph = graphOf(50, (0 until 49).map { it to it + 1 })
        val serial = GraphLayout.compute(graph, config, parallelism = 1)
        val parallel = GraphLayout.compute(graph, config, parallelism = 4)
        assertEquals(
            "parallel force accumulation must be exact, not approximate",
            serial.positions,
            parallel.positions,
        )
    }

    @Test
    fun `disconnected components all stay in bounds`() {
        // Three separate triangles with no edges between them: without gravity
        // mutual repulsion would push them to infinity.
        val edges = listOf(0 to 1, 1 to 2, 2 to 0, 3 to 4, 4 to 5, 5 to 3, 6 to 7, 7 to 8, 8 to 6)
        val result = GraphLayout.compute(graphOf(9, edges), config)
        assertAllFinite(result)
        assertInBounds(result, config)
    }

    @Test
    fun `fully disconnected graph stays finite`() {
        val result = GraphLayout.compute(graphOf(30), config)
        assertAllFinite(result)
        assertInBounds(result, config)
    }

    @Test
    fun `layout converges - connected nodes end closer than unconnected ones`() {
        // Two tight clusters joined by nothing: intra-cluster distance should
        // be clearly smaller than inter-cluster distance.
        val edges = listOf(0 to 1, 1 to 2, 0 to 2, 3 to 4, 4 to 5, 3 to 5)
        val result = GraphLayout.compute(graphOf(6, edges), config)
        val pos = result.positions.associateBy { it.id }

        fun dist(a: String, b: String): Float {
            val p = pos.getValue(a)
            val q = pos.getValue(b)
            return sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y))
        }

        val within = listOf(dist("n0", "n1"), dist("n1", "n2"), dist("n3", "n4"), dist("n4", "n5")).average()
        val between = listOf(dist("n0", "n3"), dist("n0", "n4"), dist("n1", "n5"), dist("n2", "n3")).average()
        assertTrue("clusters did not separate: within=$within between=$between", within < between)
    }

    @Test
    fun `coincident nodes are pushed apart deterministically`() {
        // A star graph pulls every leaf to the centre; the repulsion tie-break
        // must still separate them and stay finite.
        val edges = (1 until 8).map { 0 to it }
        val result = GraphLayout.compute(graphOf(8, edges), config)
        assertAllFinite(result)
        val distinct = result.positions.map { "${it.x},${it.y}" }.toSet()
        assertEquals("all positions should be distinct", result.positions.size, distinct.size)
    }

    @Test
    fun `positions stay in bounds for a non-square box`() {
        val wide = LayoutConfig(width = 1000f, height = 200f, budgetMillis = 0L)
        val result = GraphLayout.compute(graphOf(25, (0 until 24).map { it to it + 1 }), wide)
        assertAllFinite(result)
        assertInBounds(result, wide)
    }

    @Test
    fun `normalized weight spans zero to one`() {
        val result = GraphLayout.compute(graphOf(10), config)
        val weights = result.positions.map { it.normalizedWeight }
        assertEquals(0f, weights.min(), 0.001f)
        assertEquals(1f, weights.max(), 0.001f)
        assertTrue(weights.all { it in 0f..1f })
    }

    @Test
    fun `equal weights do not divide by zero`() {
        val nodes = (0 until 5).map { node("n$it", weight = 3) }
        val result = GraphLayout.compute(KnowledgeGraph(nodes, emptyList()), config)
        assertAllFinite(result)
    }

    @Test
    fun `wall clock budget stops the solve early`() {
        // A fake clock that jumps a full second per reading trips the budget on
        // the first check, so this is fast and not timing-dependent.
        var now = 0L
        val budgeted = LayoutConfig(
            width = 100f,
            height = 100f,
            budgetMillis = 50L,
            maxIterations = 10_000,
            clockNanos = { now += 1_000_000_000L; now },
        )
        val result = GraphLayout.compute(graphOf(10, listOf(0 to 1)), budgeted)
        assertTrue("expected an early stop, ran ${result.iterations}", result.iterations < 100)
        assertAllFinite(result)
    }

    @Test
    fun `iteration count scales down as the graph grows`() {
        val cfg = LayoutConfig(maxIterations = 600)
        assertTrue(cfg.iterationsFor(5) >= cfg.iterationsFor(20))
        assertTrue(cfg.iterationsFor(20) >= cfg.iterationsFor(50))
        assertTrue(cfg.iterationsFor(50) >= cfg.iterationsFor(200))
        assertTrue("must always run at least one pass", cfg.iterationsFor(100_000) >= 1)
    }

    @Test
    fun `edges referencing unknown nodes are ignored rather than crashing`() {
        val graph = KnowledgeGraph(
            nodes = listOf(node("a"), node("b", 2)),
            edges = listOf(GraphEdge("a", "ghost", RelationKind.CO_OCCURS, 1)),
        )
        val result = GraphLayout.compute(graph, config)
        assertEquals(2, result.positions.size)
        assertAllFinite(result)
    }

    @Test
    fun `layout of a real built graph is finite and in bounds`() {
        val turns = (0 until 25).map { i ->
            ConversationTurn(
                id = "q$i",
                text = "deployment pipeline stage $i with Even Realities glasses and transcription",
                kind = NodeKind.QUESTION,
                sessionId = "s${i % 3}",
                sessionLabel = "Session ${i % 3}",
            )
        }
        val graph = KnowledgeGraphBuilder().build(turns)
        assertTrue("graph should not be empty", graph.nodes.isNotEmpty())
        val result = GraphLayout.compute(graph, config, parallelism = 4)
        assertEquals(graph.nodes.size, result.positions.size)
        assertAllFinite(result)
        assertInBounds(result, config)
    }

    @Test
    fun `position lookup by id works`() {
        val result = GraphLayout.compute(graphOf(3, listOf(0 to 1)), config)
        assertTrue(result.position("n0") != null)
        assertTrue(result.position("nope") == null)
    }
}
