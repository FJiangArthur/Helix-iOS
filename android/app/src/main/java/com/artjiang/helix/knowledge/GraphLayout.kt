// Force-directed layout for KnowledgeGraph. Pure Kotlin — no android.*, no
// coroutines — so the whole solver is JVM-unit-testable and the caller decides
// which dispatcher it runs on (KnowledgeScreen uses Dispatchers.Default).
//
// Model: Fruchterman-Reingold with a Barnes-Hut-free O(n^2) repulsion (n is
// capped at ~60 term nodes plus documents, so n^2 is a few thousand ops per
// iteration — far cheaper than the allocation a quadtree would cost at this
// size), spring attraction along edges, gravity toward the centre to keep
// disconnected components on screen, and a linearly decaying temperature.
package com.artjiang.helix.knowledge

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** A laid-out node: unit-square-ish coordinates plus its display radius. */
data class NodePosition(
    val id: String,
    val x: Float,
    val y: Float,
    /** 0f..1f normalized weight, for radius/alpha in the UI. */
    val normalizedWeight: Float,
)

/**
 * Layout output. [positions] are in the coordinate space `[0, width] x
 * [0, height]` passed in [LayoutConfig], already fitted to that box.
 */
data class GraphLayoutResult(
    val positions: List<NodePosition>,
    /** Iterations actually run — may be < requested if the budget expired. */
    val iterations: Int,
) {
    private val byId: Map<String, NodePosition> =
        positions.associateBy { it.id }

    fun position(id: String): NodePosition? = byId[id]

    companion object {
        val EMPTY = GraphLayoutResult(emptyList(), 0)
    }
}

/**
 * Layout tunables.
 *
 * ON CPU BUDGET: the point is a layout that feels instant on the phone the
 * user wears all day, not one that pegs every core. [maxIterations] scales
 * DOWN as the graph grows (see [iterationsFor]) and [budgetMillis] is a hard
 * wall-clock cap checked every [BUDGET_CHECK_INTERVAL] iterations, so a big
 * graph degrades to a coarser layout instead of a frozen UI or a hot battery.
 */
data class LayoutConfig(
    val width: Float = 1f,
    val height: Float = 1f,
    /** Deterministic seed — the same seed always produces the same layout. */
    val seed: Long = 20260829L,
    /** Upper bound; the effective count comes from [iterationsFor]. */
    val maxIterations: Int = 600,
    /** Wall-clock cap in ms. 0 or negative disables the check (tests). */
    val budgetMillis: Long = 200L,
    /** Repulsion strength multiplier. */
    val repulsion: Float = 1.0f,
    /** Spring attraction multiplier. */
    val attraction: Float = 1.0f,
    /** Pull toward the centre; keeps disconnected components from drifting. */
    val gravity: Float = 0.05f,
    /**
     * Nanosecond clock, injectable so tests are not time-dependent. Default is
     * the real monotonic clock.
     */
    val clockNanos: () -> Long = System::nanoTime,
) {
    /**
     * Iteration count for [nodeCount]: small graphs get the full polish, large
     * ones get fewer passes because each pass already costs O(n^2). The budget
     * cap is the real safety net; this just avoids obviously wasted work.
     */
    fun iterationsFor(nodeCount: Int): Int = when {
        nodeCount <= 2 -> 1
        nodeCount <= 12 -> maxIterations
        nodeCount <= 30 -> (maxIterations * 3) / 4
        nodeCount <= 60 -> maxIterations / 2
        else -> maxIterations / 4
    }.coerceAtLeast(1)

    internal companion object {
        const val BUDGET_CHECK_INTERVAL = 16
    }
}

/**
 * Deterministic force-directed solver.
 *
 * Determinism guarantees (tests depend on all of these):
 *  - Initial placement comes from a seeded xorshift PRNG, never from
 *    `Math.random` or hash order.
 *  - Nodes are processed in the graph's already-sorted order.
 *  - No floating-point result depends on thread scheduling: the parallel path
 *    partitions nodes by index and each partition writes only its own slice,
 *    reading a snapshot of the previous positions.
 */
object GraphLayout {

    /**
     * Lays out [graph]. Runs synchronously on the calling thread — callers on
     * Android must hop to Dispatchers.Default first.
     *
     * [parallelism] > 1 splits force accumulation across that many threads.
     * Force accumulation is embarrassingly parallel (every node reads the same
     * immutable previous-position snapshot and writes only its own force
     * slot), so this is exact, not approximate: results are identical to the
     * serial path bit-for-bit.
     */
    fun compute(
        graph: KnowledgeGraph,
        config: LayoutConfig = LayoutConfig(),
        parallelism: Int = 1,
    ): GraphLayoutResult {
        val nodes = graph.nodes
        val n = nodes.size
        if (n == 0) return GraphLayoutResult.EMPTY

        val maxWeight = nodes.maxOf { it.weight }.coerceAtLeast(1)
        val minWeight = nodes.minOf { it.weight }
        val weightSpan = (maxWeight - minWeight).coerceAtLeast(1)

        // Single node: dead centre, no simulation.
        if (n == 1) {
            return GraphLayoutResult(
                listOf(
                    NodePosition(
                        id = nodes[0].id,
                        x = config.width / 2f,
                        y = config.height / 2f,
                        normalizedWeight = 1f,
                    ),
                ),
                iterations = 0,
            )
        }

        val index = HashMap<String, Int>(n * 2)
        for (i in 0 until n) index[nodes[i].id] = i

        val xs = FloatArray(n)
        val ys = FloatArray(n)
        val rng = XorShift(config.seed)

        // Deterministic seeding: a golden-angle spiral jittered by the PRNG.
        // A pure spiral is degenerate for symmetric graphs (forces cancel and
        // nothing moves); the jitter breaks the symmetry reproducibly.
        val cx = config.width / 2f
        val cy = config.height / 2f
        val spread = min(config.width, config.height) * 0.4f
        for (i in 0 until n) {
            val t = (i + 1).toFloat() / n
            val angle = i * GOLDEN_ANGLE
            val radius = spread * sqrt(t)
            xs[i] = cx + radius * kotlin.math.cos(angle) + (rng.nextFloat() - 0.5f) * spread * 0.05f
            ys[i] = cy + radius * kotlin.math.sin(angle) + (rng.nextFloat() - 0.5f) * spread * 0.05f
        }

        // Edge arrays: flat primitives, no per-iteration allocation.
        val validEdges = graph.edges.filter { index.containsKey(it.source) && index.containsKey(it.target) }
        val edgeCount = validEdges.size
        val edgeA = IntArray(edgeCount)
        val edgeB = IntArray(edgeCount)
        val edgeW = FloatArray(edgeCount)
        val maxEdgeWeight = validEdges.maxOfOrNull { it.weight }?.coerceAtLeast(1) ?: 1
        for (e in 0 until edgeCount) {
            val edge = validEdges[e]
            edgeA[e] = index.getValue(edge.source)
            edgeB[e] = index.getValue(edge.target)
            // Normalized so a single very heavy edge cannot collapse the graph.
            edgeW[e] = 0.5f + 0.5f * (edge.weight.toFloat() / maxEdgeWeight)
        }

        val area = config.width * config.height
        // Fruchterman-Reingold ideal edge length.
        val k = sqrt(area / n) * 0.85f
        val kSquared = k * k

        val fx = FloatArray(n)
        val fy = FloatArray(n)

        val iterations = config.iterationsFor(n)
        val budgetNanos = if (config.budgetMillis > 0) config.budgetMillis * 1_000_000L else Long.MAX_VALUE
        val start = config.clockNanos()

        val workers = parallelism.coerceIn(1, MAX_PARALLELISM)
        val pool = if (workers > 1 && n >= PARALLEL_NODE_THRESHOLD) {
            java.util.concurrent.Executors.newFixedThreadPool(workers - 1) { runnable ->
                Thread(runnable, "helix-graph-layout").apply { isDaemon = true }
            }
        } else {
            null
        }

        var ran = 0
        try {
            for (iter in 0 until iterations) {
                if (iter % LayoutConfig.BUDGET_CHECK_INTERVAL == 0 &&
                    iter > 0 &&
                    config.clockNanos() - start > budgetNanos
                ) {
                    break
                }
                java.util.Arrays.fill(fx, 0f)
                java.util.Arrays.fill(fy, 0f)

                if (pool == null) {
                    accumulateRepulsion(0, n, n, xs, ys, fx, fy, kSquared, config.repulsion)
                } else {
                    accumulateRepulsionParallel(pool, workers, n, xs, ys, fx, fy, kSquared, config.repulsion)
                }

                // Attraction along edges — serial: edge count is small and the
                // scatter-write pattern would need locks to parallelise.
                for (e in 0 until edgeCount) {
                    val a = edgeA[e]
                    val b = edgeB[e]
                    var dx = xs[a] - xs[b]
                    var dy = ys[a] - ys[b]
                    var dist = sqrt(dx * dx + dy * dy)
                    if (dist < EPSILON) {
                        dx = EPSILON
                        dy = 0f
                        dist = EPSILON
                    }
                    val force = (dist * dist / k) * edgeW[e] * config.attraction
                    val ux = dx / dist
                    val uy = dy / dist
                    fx[a] -= ux * force
                    fy[a] -= uy * force
                    fx[b] += ux * force
                    fy[b] += uy * force
                }

                // Gravity toward the centre.
                for (i in 0 until n) {
                    fx[i] += (cx - xs[i]) * config.gravity * k * 0.1f
                    fy[i] += (cy - ys[i]) * config.gravity * k * 0.1f
                }

                // Displace, capped by a linearly cooling temperature.
                val temperature = k * 0.1f * (1f - iter.toFloat() / iterations)
                for (i in 0 until n) {
                    val d = sqrt(fx[i] * fx[i] + fy[i] * fy[i])
                    if (d < EPSILON) continue
                    val limited = min(d, temperature)
                    val nx = xs[i] + fx[i] / d * limited
                    val ny = ys[i] + fy[i] / d * limited
                    // Guard against a pathological force producing NaN/Inf; a
                    // single bad value would poison every later iteration.
                    if (nx.isFinite() && ny.isFinite()) {
                        xs[i] = nx
                        ys[i] = ny
                    }
                }
                ran = iter + 1
            }
        } finally {
            pool?.shutdown()
        }

        return GraphLayoutResult(
            positions = fitToBox(nodes, xs, ys, config, minWeight, weightSpan),
            iterations = ran,
        )
    }

    /**
     * Repulsion for nodes in `[from, to)` against all [n] nodes. Reads only
     * xs/ys (unmodified during accumulation) and writes only its own slice of
     * fx/fy, so partitions are independent and the result is order-invariant.
     */
    private fun accumulateRepulsion(
        from: Int,
        to: Int,
        n: Int,
        xs: FloatArray,
        ys: FloatArray,
        fx: FloatArray,
        fy: FloatArray,
        kSquared: Float,
        strength: Float,
    ) {
        for (i in from until to) {
            var accX = 0f
            var accY = 0f
            val xi = xs[i]
            val yi = ys[i]
            for (j in 0 until n) {
                if (i == j) continue
                var dx = xi - xs[j]
                var dy = yi - ys[j]
                var distSq = dx * dx + dy * dy
                if (distSq < EPSILON_SQ) {
                    // Coincident nodes: deterministic nudge by index parity so
                    // the tie is broken the same way on every run.
                    dx = if (i < j) EPSILON else -EPSILON
                    dy = if ((i + j) % 2 == 0) EPSILON else -EPSILON
                    distSq = dx * dx + dy * dy
                }
                val dist = sqrt(distSq)
                val force = kSquared / dist * strength
                accX += dx / dist * force
                accY += dy / dist * force
            }
            fx[i] = accX
            fy[i] = accY
        }
    }

    private fun accumulateRepulsionParallel(
        pool: java.util.concurrent.ExecutorService,
        workers: Int,
        n: Int,
        xs: FloatArray,
        ys: FloatArray,
        fx: FloatArray,
        fy: FloatArray,
        kSquared: Float,
        strength: Float,
    ) {
        val chunk = (n + workers - 1) / workers
        val futures = ArrayList<java.util.concurrent.Future<*>>(workers - 1)
        // Workers 1..n-1 go to the pool; the calling thread does chunk 0, so
        // we use every core including this one.
        for (w in 1 until workers) {
            val from = w * chunk
            if (from >= n) break
            val to = min(from + chunk, n)
            futures.add(
                pool.submit {
                    accumulateRepulsion(from, to, n, xs, ys, fx, fy, kSquared, strength)
                },
            )
        }
        accumulateRepulsion(0, min(chunk, n), n, xs, ys, fx, fy, kSquared, strength)
        for (f in futures) f.get()
    }

    /**
     * Rescales the simulated cloud into the configured box with a margin.
     * Degenerate spans (every node on one line) fall back to centring, which
     * is what keeps a 2-node or fully-coincident graph finite.
     */
    private fun fitToBox(
        nodes: List<GraphNode>,
        xs: FloatArray,
        ys: FloatArray,
        config: LayoutConfig,
        minWeight: Int,
        weightSpan: Int,
    ): List<NodePosition> {
        val n = nodes.size
        var minX = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        for (i in 0 until n) {
            val x = if (xs[i].isFinite()) xs[i] else 0f
            val y = if (ys[i].isFinite()) ys[i] else 0f
            xs[i] = x
            ys[i] = y
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
        val marginX = config.width * MARGIN_FRACTION
        val marginY = config.height * MARGIN_FRACTION
        val boxW = config.width - marginX * 2f
        val boxH = config.height - marginY * 2f
        val spanX = maxX - minX
        val spanY = maxY - minY
        // Uniform scale on both axes preserves the layout's aspect; using the
        // smaller factor guarantees it fits.
        val scale = when {
            spanX > EPSILON && spanY > EPSILON -> min(boxW / spanX, boxH / spanY)
            spanX > EPSILON -> boxW / spanX
            spanY > EPSILON -> boxH / spanY
            else -> 1f
        }
        val usedW = spanX * scale
        val usedH = spanY * scale
        val offsetX = marginX + (boxW - usedW) / 2f
        val offsetY = marginY + (boxH - usedH) / 2f

        return List(n) { i ->
            val node = nodes[i]
            val x = if (spanX > EPSILON) offsetX + (xs[i] - minX) * scale else config.width / 2f
            val y = if (spanY > EPSILON) offsetY + (ys[i] - minY) * scale else config.height / 2f
            NodePosition(
                id = node.id,
                x = if (x.isFinite()) x else config.width / 2f,
                y = if (y.isFinite()) y else config.height / 2f,
                normalizedWeight = ((node.weight - minWeight).toFloat() / weightSpan).coerceIn(0f, 1f),
            )
        }
    }

    /**
     * Seeded xorshift64*. Chosen over java.util.Random because its exact bit
     * sequence is specified here in-repo — no dependence on a JDK class whose
     * algorithm could theoretically differ across runtimes.
     */
    private class XorShift(seed: Long) {
        private var state: Long = if (seed == 0L) 0x9E3779B97F4A7C15uL.toLong() else seed

        fun nextFloat(): Float {
            state = state xor (state shl 13)
            state = state xor (state ushr 7)
            state = state xor (state shl 17)
            // Top 24 bits -> [0, 1); abs() guards the sign bit.
            return (abs(state ushr 40).toFloat() / (1 shl 24).toFloat()).coerceIn(0f, 1f)
        }
    }

    private const val EPSILON = 1e-4f
    private const val EPSILON_SQ = EPSILON * EPSILON
    private const val MARGIN_FRACTION = 0.08f
    private const val GOLDEN_ANGLE = 2.39996323f
    private const val MAX_PARALLELISM = 8

    /**
     * Below this node count the serial path wins: measured on this codebase's
     * default caps (~125 nodes) the pool costs more in thread handoff than the
     * O(n^2) force loop saves. Parallelism only pays off once a caller raises
     * GraphBuildConfig's node caps well past the defaults, so the pool is
     * opt-in by size rather than always-on.
     */
    private const val PARALLEL_NODE_THRESHOLD = 400
}
