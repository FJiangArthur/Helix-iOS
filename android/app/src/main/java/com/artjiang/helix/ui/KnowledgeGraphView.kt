// Canvas rendering for the conversation knowledge graph: pan/zoom, weighted
// nodes and edges, tap-to-select with a detail panel. All the maths lives in
// com.artjiang.helix.knowledge (pure Kotlin); this file only draws it.
package com.artjiang.helix.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.artjiang.helix.knowledge.GraphLayoutResult
import com.artjiang.helix.knowledge.KnowledgeGraph
import com.artjiang.helix.knowledge.NodeKind
import com.artjiang.helix.knowledge.RelationKind
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Interactive graph canvas.
 *
 * [layout] positions are in the normalized space the caller solved in (see
 * [com.artjiang.helix.knowledge.LayoutConfig] width/height); this view scales
 * them to the actual canvas, so the same solved layout survives a fold/unfold
 * without re-running the solver.
 */
@Composable
fun KnowledgeGraphView(
    graph: KnowledgeGraph,
    layout: GraphLayoutResult,
    layoutWidth: Float,
    layoutHeight: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = HelixTheme.tokens
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current

    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }

    BoxWithConstraints(modifier = modifier) {
        val widthClass = helixWidthClass(maxWidth)
        // Taller aspect on narrow screens (Fold cover) so the graph still has
        // room to breathe; wider screens get a shallower, wider field.
        val aspect = when (widthClass) {
            HelixWidthClass.Narrow -> 0.95f
            HelixWidthClass.Standard -> 1.05f
            HelixWidthClass.Wide -> 1.5f
        }

        val canvasModifier = Modifier
            .fillMaxWidth()
            .aspectRatio(aspect)
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    scale = (scale * zoom).coerceIn(MIN_SCALE, MAX_SCALE)
                    offsetX += pan.x
                    offsetY += pan.y
                }
            }
            .pointerInput(graph, layout, layoutWidth, layoutHeight) {
                detectTapGestures { tap ->
                    val hit = hitTest(
                        tap = tap,
                        graph = graph,
                        layout = layout,
                        layoutWidth = layoutWidth,
                        layoutHeight = layoutHeight,
                        canvasWidth = size.width.toFloat(),
                        canvasHeight = size.height.toFloat(),
                        scale = scale,
                        offsetX = offsetX,
                        offsetY = offsetY,
                        maxRadiusPx = with(density) { MAX_NODE_RADIUS.toPx() },
                        minRadiusPx = with(density) { MIN_NODE_RADIUS.toPx() },
                        touchSlopPx = with(density) { TOUCH_SLOP.toPx() },
                    )
                    // Tapping empty space clears the selection.
                    onSelect(hit)
                }
            }

        Canvas(modifier = canvasModifier) {
            drawGraph(
                graph = graph,
                layout = layout,
                layoutWidth = layoutWidth,
                layoutHeight = layoutHeight,
                scale = scale,
                offsetX = offsetX,
                offsetY = offsetY,
                selectedId = selectedId,
                tokens = tokens,
                measurer = measurer,
                maxRadiusPx = MAX_NODE_RADIUS.toPx(),
                minRadiusPx = MIN_NODE_RADIUS.toPx(),
                labelOnNarrow = widthClass != HelixWidthClass.Narrow,
            )
        }
    }
}

/** Maps a solved position into canvas pixels under the current pan/zoom. */
private fun project(
    x: Float,
    y: Float,
    layoutWidth: Float,
    layoutHeight: Float,
    canvasWidth: Float,
    canvasHeight: Float,
    scale: Float,
    offsetX: Float,
    offsetY: Float,
): Offset {
    val nx = if (layoutWidth > 0f) x / layoutWidth else 0.5f
    val ny = if (layoutHeight > 0f) y / layoutHeight else 0.5f
    // Zoom about the canvas centre so pinching feels anchored.
    val cx = canvasWidth / 2f
    val cy = canvasHeight / 2f
    return Offset(
        x = cx + (nx * canvasWidth - cx) * scale + offsetX,
        y = cy + (ny * canvasHeight - cy) * scale + offsetY,
    )
}

private fun radiusFor(normalizedWeight: Float, minPx: Float, maxPx: Float): Float =
    // sqrt so *area* tracks weight — a linear radius exaggerates big nodes.
    minPx + (maxPx - minPx) * sqrt(normalizedWeight.coerceIn(0f, 1f))

private fun hitTest(
    tap: Offset,
    graph: KnowledgeGraph,
    layout: GraphLayoutResult,
    layoutWidth: Float,
    layoutHeight: Float,
    canvasWidth: Float,
    canvasHeight: Float,
    scale: Float,
    offsetX: Float,
    offsetY: Float,
    maxRadiusPx: Float,
    minRadiusPx: Float,
    touchSlopPx: Float,
): String? {
    var best: String? = null
    var bestDistance = Float.MAX_VALUE
    for (node in graph.nodes) {
        val pos = layout.position(node.id) ?: continue
        val p = project(
            pos.x, pos.y, layoutWidth, layoutHeight,
            canvasWidth, canvasHeight, scale, offsetX, offsetY,
        )
        val dx = tap.x - p.x
        val dy = tap.y - p.y
        val distance = sqrt(dx * dx + dy * dy)
        // Generous target: the drawn radius plus a slop ring, so small nodes
        // are still tappable with a fingertip.
        val target = radiusFor(pos.normalizedWeight, minRadiusPx, maxRadiusPx) * scale + touchSlopPx
        if (distance <= target && distance < bestDistance) {
            bestDistance = distance
            best = node.id
        }
    }
    return best
}

private fun DrawScope.drawGraph(
    graph: KnowledgeGraph,
    layout: GraphLayoutResult,
    layoutWidth: Float,
    layoutHeight: Float,
    scale: Float,
    offsetX: Float,
    offsetY: Float,
    selectedId: String?,
    tokens: HelixTokens,
    measurer: TextMeasurer,
    maxRadiusPx: Float,
    minRadiusPx: Float,
    labelOnNarrow: Boolean,
) {
    if (graph.nodes.isEmpty()) return

    val neighborIds: Set<String> = if (selectedId != null) {
        graph.neighborsOf(selectedId).mapTo(HashSet()) { it.id }
    } else {
        emptySet()
    }

    val maxEdgeWeight = graph.edges.maxOfOrNull { it.weight }?.coerceAtLeast(1) ?: 1

    // Edges first, so nodes paint on top.
    for (edge in graph.edges) {
        val a = layout.position(edge.source) ?: continue
        val b = layout.position(edge.target) ?: continue
        val pa = project(a.x, a.y, layoutWidth, layoutHeight, size.width, size.height, scale, offsetX, offsetY)
        val pb = project(b.x, b.y, layoutWidth, layoutHeight, size.width, size.height, scale, offsetX, offsetY)

        val touchesSelection = selectedId != null &&
            (edge.source == selectedId || edge.target == selectedId)
        val baseAlpha = 0.18f + 0.5f * (edge.weight.toFloat() / maxEdgeWeight)
        val alpha = when {
            selectedId == null -> baseAlpha
            touchesSelection -> min(1f, baseAlpha + 0.35f)
            // Dim everything unrelated so the selected neighbourhood reads.
            else -> baseAlpha * 0.25f
        }
        val color = when (edge.relation) {
            RelationKind.CO_OCCURS -> tokens.support
            RelationKind.MENTIONS -> tokens.borderStrong
            RelationKind.ANSWERS -> tokens.accent
            RelationKind.CONTAINS -> tokens.gold
        }
        drawLine(
            color = color.copy(alpha = alpha.coerceIn(0f, 1f)),
            start = pa,
            end = pb,
            strokeWidth = (0.8f + 1.6f * (edge.weight.toFloat() / maxEdgeWeight)).dp.toPx() *
                scale.coerceIn(0.6f, 1.6f),
        )
    }

    for (node in graph.nodes) {
        val pos = layout.position(node.id) ?: continue
        val p = project(pos.x, pos.y, layoutWidth, layoutHeight, size.width, size.height, scale, offsetX, offsetY)
        val radius = radiusFor(pos.normalizedWeight, minRadiusPx, maxRadiusPx) * scale

        // Cull offscreen nodes — cheap, and matters when zoomed in.
        if (p.x < -radius || p.y < -radius || p.x > size.width + radius || p.y > size.height + radius) {
            continue
        }

        val isSelected = node.id == selectedId
        val isNeighbor = node.id in neighborIds
        val dimmed = selectedId != null && !isSelected && !isNeighbor
        val fill = nodeColor(node.kind, tokens)
        val alpha = if (dimmed) 0.25f else 1f

        drawCircle(
            color = fill.copy(alpha = alpha),
            radius = radius,
            center = p,
        )
        drawCircle(
            color = (if (isSelected) tokens.ink else tokens.surface).copy(alpha = alpha),
            radius = radius,
            center = p,
            style = Stroke(width = (if (isSelected) 2.5f else 1f).dp.toPx()),
        )

        // Label only the nodes big enough to carry one, and only when the
        // screen is wide enough for text not to become clutter.
        val showLabel = !dimmed &&
            (isSelected || (labelOnNarrow && (pos.normalizedWeight > LABEL_WEIGHT_THRESHOLD || isNeighbor)))
        if (showLabel && radius > minRadiusPx * 0.8f) {
            val text = node.label.take(LABEL_MAX_CHARS)
            val measured = measurer.measure(
                text = text,
                style = TextStyle(fontSize = 11.sp, color = tokens.ink),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            drawText(
                textLayoutResult = measured,
                topLeft = Offset(
                    x = p.x - measured.size.width / 2f,
                    y = p.y + radius + 2.dp.toPx(),
                ),
            )
        }
    }
}

private fun nodeColor(kind: NodeKind, tokens: HelixTokens): Color = when (kind) {
    NodeKind.TOPIC -> tokens.support
    NodeKind.ENTITY -> tokens.accent
    NodeKind.QUESTION -> tokens.gold
    NodeKind.ANSWER -> tokens.accentDeep
    NodeKind.KNOWLEDGE -> tokens.success
    NodeKind.SESSION -> tokens.warning
}

/** Node colour for a kind — shared by the canvas, legend, and detail panel. */
@Composable
fun kindSwatch(kind: NodeKind, tokens: HelixTokens): Color = nodeColor(kind, tokens)

/** Human label for a node kind, shared by the legend and the detail panel. */
fun nodeKindLabel(kind: NodeKind): String = when (kind) {
    NodeKind.TOPIC -> "Topic"
    NodeKind.ENTITY -> "Name"
    NodeKind.QUESTION -> "Question"
    NodeKind.ANSWER -> "Answer"
    NodeKind.KNOWLEDGE -> "Saved"
    NodeKind.SESSION -> "Session"
}

/** Colour swatch legend; wraps so it survives the Fold cover screen. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GraphLegend(kinds: List<NodeKind>, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
    ) {
        for (kind in kinds) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(9.dp)
                        .background(nodeColor(kind, tokens), CircleShape),
                )
                Text(
                    text = nodeKindLabel(kind),
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.inkSecondary,
                )
            }
        }
    }
}

private val MIN_NODE_RADIUS: Dp = 5.dp
private val MAX_NODE_RADIUS: Dp = 18.dp
private val TOUCH_SLOP: Dp = 10.dp
private const val MIN_SCALE = 0.4f
private const val MAX_SCALE = 5f
private const val LABEL_WEIGHT_THRESHOLD = 0.35f
private const val LABEL_MAX_CHARS = 22
