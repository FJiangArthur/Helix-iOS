// Knowledge tab: bucket picker + add field, then the bucket's items — facts as
// a swipeable deck of LinenCards. Port of ios/Runner/NativeKnowledgeView.swift
// (TabView .page -> HorizontalPager).
package com.artjiang.helix.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AccountTree
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.Checklist
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.R
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import com.artjiang.helix.data.KnowledgeRepository
import com.artjiang.helix.knowledge.GraphBuildConfig
import com.artjiang.helix.knowledge.GraphLayout
import com.artjiang.helix.knowledge.GraphLayoutResult
import com.artjiang.helix.knowledge.KnowledgeGraph
import com.artjiang.helix.knowledge.KnowledgeGraphBuilder
import com.artjiang.helix.knowledge.LayoutConfig
import com.artjiang.helix.knowledge.NodeKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Knowledge tab modes: the flat library, or the derived conversation graph. */
private enum class KnowledgeView { LIBRARY, GRAPH }

@Composable
fun KnowledgeScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    val items by bridge.knowledgeItems.collectAsStateWithLifecycle()
    val sessions by bridge.sessions.collectAsStateWithLifecycle()
    // The LIVE conversation, not just explicitly-saved sessions: the feed is
    // now persisted, carries real per-entry kinds, and links answers to their
    // question — so the graph reflects what was actually said.
    val feed by bridge.feed.collectAsStateWithLifecycle()
    var bucket by remember { mutableStateOf(KnowledgeBucket.PROJECTS) }
    var draft by remember { mutableStateOf("") }
    var view by remember { mutableStateOf(KnowledgeView.LIBRARY) }

    val bucketItems = items.filter { it.bucket == bucket }.sortedByDescending { it.createdAtMillis }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = HelixSpacing.screen)
            .padding(top = HelixSpacing.s4, bottom = HelixSpacing.s24),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.cardGap),
    ) {
        HelixSegmentedRow(
            entries = KnowledgeView.entries,
            selected = view,
            label = { if (it == KnowledgeView.LIBRARY) "Library" else "Graph" },
        ) { entry -> view = entry }

        if (view == KnowledgeView.GRAPH) {
            KnowledgeGraphSection(items = items, sessions = sessions, feed = feed)
            return@Column
        }

        HelixSection(
            title = "Knowledge",
            subtitle = bucketSummary(bucket, bucketItems.size),
            icon = Icons.Outlined.AutoStories,
            tint = tokens.support,
        ) {
            HelixSegmentedRow(
                entries = KnowledgeBucket.entries,
                selected = bucket,
                label = ::bucketTitle,
            ) { entry -> bucket = entry }

            TagRow(
                values = KnowledgeBucket.entries.map { entry ->
                    "${items.count { it.bucket == entry }} ${bucketTitle(entry).lowercase()}"
                },
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text(bucketPlaceholder(bucket), color = tokens.inkMuted) },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                    shape = MaterialTheme.shapes.medium,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = tokens.surface,
                        unfocusedContainerColor = tokens.surface,
                        focusedBorderColor = tokens.accent,
                        unfocusedBorderColor = tokens.borderStrong,
                        cursorColor = tokens.accentDeep,
                    ),
                )
                FilledIconButton(
                    onClick = {
                        bridge.addKnowledge(bucket, draft)
                        draft = ""
                    },
                    enabled = draft.isNotBlank(),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = tokens.accent,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        disabledContainerColor = tokens.accentTint,
                        disabledContentColor = tokens.inkMuted,
                    ),
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = "Add ${bucketTitle(bucket).lowercase()}")
                }
            }
        }

        if (bucketItems.isEmpty()) {
            LinenCard {
                EmptyState(
                    title = "Nothing here yet",
                    detail = "Use the field above to add ${bucketTitle(bucket).lowercase()}.",
                    icon = bucketIcon(bucket),
                    illustration = painterResource(R.drawable.helix_empty_knowledge),
                )
            }
        } else if (bucket == KnowledgeBucket.FACTS) {
            FactCarousel(facts = bucketItems, onDelete = bridge::removeKnowledge)
        } else {
            LinenCard(leftRule = tokens.support) {
                bucketItems.forEachIndexed { index, item ->
                    KnowledgeRow(item = item, icon = bucketIcon(bucket), onDelete = { bridge.removeKnowledge(item.id) })
                    if (index < bucketItems.size - 1) HairlineDivider()
                }
            }
        }
    }
}

/**
 * The derived conversation graph: build + layout off the main thread, then a
 * pan/zoom canvas with tap-to-select and a detail panel for the selection.
 *
 * CPU BUDGET: both the build and the solve run on [Dispatchers.Default] inside
 * `produceState`, so composition never blocks. The solver's own iteration
 * scaling plus a wall-clock cap (see [LayoutConfig]) keep it in the
 * "instant" range instead of pegging the CPU on a phone worn all day.
 */
@Composable
private fun KnowledgeGraphSection(
    items: List<KnowledgeItem>,
    sessions: List<com.artjiang.helix.core.SessionSummary>,
    feed: List<com.artjiang.helix.FeedEntry>,
) {
    val tokens = HelixTheme.tokens
    var selectedId by remember { mutableStateOf<String?>(null) }

    val cores = remember { Runtime.getRuntime().availableProcessors() }
    // Leave a core for the UI thread; the solver is a background nicety, not
    // the priority. Capped at 4 — beyond that the O(n^2) work at this graph
    // size is dominated by thread handoff, not compute.
    val parallelism = remember(cores) { (cores - 1).coerceIn(1, 4) }

    val state by produceState<GraphState?>(initialValue = null, items, sessions, feed) {
        value = withContext(Dispatchers.Default) {
            val turns = KnowledgeRepository.conversationTurns(items, sessions) +
                KnowledgeRepository.feedTurns(
                    feed.map { entry ->
                        com.artjiang.helix.data.FeedTurnInput(
                            id = entry.id,
                            kind = when (entry.kind) {
                                com.artjiang.helix.FeedEntry.Kind.QUESTION -> NodeKind.QUESTION
                                com.artjiang.helix.FeedEntry.Kind.ANSWER -> NodeKind.ANSWER
                                else -> NodeKind.KNOWLEDGE
                            },
                            text = entry.text,
                            question = entry.question,
                        )
                    },
                )
            val graph = KnowledgeGraphBuilder(GraphBuildConfig()).build(turns)
            val config = LayoutConfig(
                width = LAYOUT_SPAN,
                height = LAYOUT_SPAN,
                budgetMillis = LAYOUT_BUDGET_MILLIS,
            )
            GraphState(graph, GraphLayout.compute(graph, config, parallelism))
        }
    }

    // A selection pointing at a node that no longer exists would render a
    // stale detail panel, so drop it whenever the graph changes.
    val graph = state?.graph
    LaunchedEffect(graph) {
        if (graph != null && selectedId != null && graph.node(selectedId!!) == null) {
            selectedId = null
        }
    }

    val current = state
    HelixSection(
        title = "Conversation graph",
        subtitle = when {
            current == null -> "Building…"
            current.graph.isEmpty -> "Nothing to connect yet"
            else -> "${current.graph.nodes.size} nodes · ${current.graph.edges.size} links"
        },
        icon = Icons.Outlined.AccountTree,
        tint = tokens.support,
    ) {
        if (current == null) {
            Text(
                text = "Deriving topics and connections…",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
            return@HelixSection
        }
        if (current.graph.isEmpty) {
            EmptyState(
                title = "No graph yet",
                detail = "Save knowledge or record a session, and recurring topics " +
                    "and names will link up here.",
                icon = Icons.Outlined.AccountTree,
            )
            return@HelixSection
        }

        Text(
            text = "Pinch to zoom, drag to pan, tap a node to follow its connections.",
            style = MaterialTheme.typography.labelSmall,
            color = tokens.inkMuted,
        )

        KnowledgeGraphView(
            graph = current.graph,
            layout = current.layout,
            layoutWidth = LAYOUT_SPAN,
            layoutHeight = LAYOUT_SPAN,
            selectedId = selectedId,
            onSelect = { selectedId = it },
            modifier = Modifier.fillMaxWidth(),
        )

        GraphLegend(
            kinds = current.graph.nodes.map { it.kind }.distinct().sortedBy { it.ordinal },
        )
    }

    val selectedNode = selectedId?.let { current?.graph?.node(it) }
    if (current != null && selectedNode != null) {
        GraphDetailCard(
            graph = current.graph,
            node = selectedNode,
            onSelect = { selectedId = it },
        )
    }
}

private data class GraphState(val graph: KnowledgeGraph, val layout: GraphLayoutResult)

/**
 * "Parse along the details" for the tapped node: what it is, the source text
 * if it is a document node, and its neighbours as tappable rows so the user
 * can walk the graph without going back to the canvas.
 */
@Composable
private fun GraphDetailCard(
    graph: KnowledgeGraph,
    node: com.artjiang.helix.knowledge.GraphNode,
    onSelect: (String?) -> Unit,
) {
    val tokens = HelixTheme.tokens
    val neighbors = remember(graph, node.id) { graph.neighborsOf(node.id) }

    LinenCard(leftRule = tokens.accent) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = node.label,
                    style = MaterialTheme.typography.titleMedium,
                    color = tokens.ink,
                )
                Text(
                    text = "${nodeKindLabel(node.kind)} · appears ${node.weight}×",
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.inkMuted,
                )
            }
            IconButton(onClick = { onSelect(null) }) {
                Icon(
                    Icons.Outlined.Close,
                    contentDescription = "Clear selection",
                    tint = tokens.inkSecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        if (node.detail.isNotBlank()) {
            Text(
                text = node.detail,
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
        }

        if (neighbors.isEmpty()) {
            Text(
                text = "No connections yet.",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkMuted,
            )
        } else {
            HairlineDivider()
            Text(
                text = "Connected to ${neighbors.size}",
                style = MaterialTheme.typography.labelMedium,
                color = tokens.inkSecondary,
            )
            for (neighbor in neighbors.take(MAX_NEIGHBOR_ROWS)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(neighbor.id) }
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(kindSwatch(neighbor.kind, tokens), CircleShape),
                    )
                    Text(
                        text = neighbor.label,
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.ink,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = nodeKindLabel(neighbor.kind),
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.inkMuted,
                    )
                }
            }
        }
    }
}

private const val LAYOUT_SPAN = 1000f
private const val LAYOUT_BUDGET_MILLIS = 200L
private const val MAX_NEIGHBOR_ROWS = 12

@Composable
private fun KnowledgeRow(item: KnowledgeItem, icon: ImageVector, onDelete: () -> Unit) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconBadge(icon = icon, tint = tokens.support, size = 32.dp)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = item.text,
                style = MaterialTheme.typography.bodyMedium,
                color = tokens.ink,
            )
            Text(
                text = "${item.source} · ${relativeLabel(item.createdAtMillis)}",
                style = MaterialTheme.typography.labelSmall,
                color = tokens.inkMuted,
            )
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Outlined.Delete,
                contentDescription = "Delete item",
                tint = tokens.inkSecondary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/**
 * Swipeable fact deck, mirroring the iOS `FactCardCarousel`: one fact per page
 * (a sage-ruled LinenCard with a gold check) plus an "N of M" counter and dots.
 */
@Composable
private fun FactCarousel(facts: List<KnowledgeItem>, onDelete: (String) -> Unit) {
    val tokens = HelixTheme.tokens
    val pagerState = rememberPagerState(pageCount = { facts.size })

    Column(verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth().height(176.dp),
            pageSpacing = HelixSpacing.s8,
        ) { page ->
            val fact = facts[page]
            LinenCard(
                leftRule = tokens.support,
                modifier = Modifier.fillMaxSize().padding(vertical = 2.dp),
            ) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Outlined.Verified,
                        contentDescription = null,
                        tint = tokens.gold,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.size(6.dp))
                    Text(
                        text = "Fact",
                        style = MaterialTheme.typography.labelMedium,
                        color = onTintColor(tokens.gold),
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = "${page + 1} of ${facts.size}",
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.inkMuted,
                    )
                }

                Text(
                    text = fact.text,
                    style = MaterialTheme.typography.bodyLarge,
                    color = tokens.ink,
                    modifier = Modifier.weight(1f),
                )

                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = fact.source.ifBlank { "Manual" },
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.inkMuted,
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { onDelete(fact.id) }, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Outlined.Delete,
                            contentDescription = "Delete fact",
                            tint = tokens.inkSecondary,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
        ) {
            repeat(facts.size) { index ->
                Box(
                    modifier = Modifier
                        .padding(horizontal = 3.dp)
                        .size(6.dp)
                        .background(
                            if (index == pagerState.currentPage) tokens.accent else tokens.borderStrong,
                            CircleShape,
                        ),
                )
            }
        }
    }
}

private fun bucketTitle(bucket: KnowledgeBucket): String = when (bucket) {
    KnowledgeBucket.PROJECTS -> "Projects"
    KnowledgeBucket.FACTS -> "Facts"
    KnowledgeBucket.MEMORIES -> "Memories"
    KnowledgeBucket.TODOS -> "Todos"
}

private fun bucketPlaceholder(bucket: KnowledgeBucket): String = when (bucket) {
    KnowledgeBucket.PROJECTS -> "Project name"
    KnowledgeBucket.FACTS -> "Fact to remember"
    KnowledgeBucket.MEMORIES -> "Conversation memory"
    KnowledgeBucket.TODOS -> "Follow-up item"
}

private fun bucketIcon(bucket: KnowledgeBucket): ImageVector = when (bucket) {
    KnowledgeBucket.PROJECTS -> Icons.Outlined.Folder
    KnowledgeBucket.FACTS -> Icons.Outlined.Verified
    KnowledgeBucket.MEMORIES -> Icons.Outlined.Psychology
    KnowledgeBucket.TODOS -> Icons.Outlined.Checklist
}

private fun bucketSummary(bucket: KnowledgeBucket, count: Int): String = when (bucket) {
    KnowledgeBucket.PROJECTS -> "$count projects"
    KnowledgeBucket.FACTS -> "$count facts available for RAG"
    KnowledgeBucket.MEMORIES -> "$count conversation memories"
    KnowledgeBucket.TODOS -> "$count follow-up items"
}
