// Port of ios/Runner/NativeKnowledgeView.swift, including the swipeable fact
// card deck (TabView .page -> HorizontalPager).
package com.artjiang.helix.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem

@Composable
fun KnowledgeScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val items by bridge.knowledgeItems.collectAsStateWithLifecycle()
    var bucket by remember { mutableStateOf(KnowledgeBucket.PROJECTS) }
    var draft by remember { mutableStateOf("") }

    val bucketItems = items.filter { it.bucket == bucket.name }.sortedByDescending { it.createdAtMillis }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HelixSection(title = "Knowledge", subtitle = bucketSummary(bucket, bucketItems.size)) {
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                KnowledgeBucket.entries.forEachIndexed { index, entry ->
                    SegmentedButton(
                        selected = bucket == entry,
                        onClick = { bucket = entry },
                        shape = SegmentedButtonDefaults.itemShape(index, KnowledgeBucket.entries.size),
                    ) {
                        Text(bucketTitle(entry))
                    }
                }
            }

            TagRow(
                values = KnowledgeBucket.entries.map { entry ->
                    "${items.count { it.bucket == entry.name }} ${bucketTitle(entry).lowercase()}"
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
                    placeholder = { Text(bucketPlaceholder(bucket)) },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                )
                FilledTonalIconButton(
                    onClick = {
                        bridge.addKnowledge(bucket, draft)
                        draft = ""
                    },
                    enabled = draft.isNotBlank(),
                ) {
                    Icon(Icons.Filled.Add, contentDescription = "Add ${bucketTitle(bucket).lowercase()}")
                }
            }

            HairlineDivider()

            if (bucketItems.isEmpty()) {
                EmptyState(
                    title = "Nothing here yet",
                    detail = "Use the field above to add ${bucketTitle(bucket).lowercase()}.",
                    icon = bucketIcon(bucket),
                )
            } else if (bucket == KnowledgeBucket.FACTS) {
                FactCarousel(facts = bucketItems, onDelete = bridge::removeKnowledge)
            } else {
                bucketItems.forEachIndexed { index, item ->
                    KnowledgeRow(item = item, icon = bucketIcon(bucket), onDelete = { bridge.removeKnowledge(item.id) })
                    if (index < bucketItems.size - 1) HairlineDivider()
                }
            }
        }
    }
}

@Composable
private fun KnowledgeRow(item: KnowledgeItem, icon: ImageVector, onDelete: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = HelixColors.Teal, modifier = Modifier.size(20.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = item.text,
                style = MaterialTheme.typography.bodyMedium,
                color = HelixColors.Ink,
            )
            Text(
                text = "${item.source} - ${relativeLabel(item.createdAtMillis)}",
                style = MaterialTheme.typography.labelSmall,
                color = HelixColors.SecondaryInk,
            )
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Filled.Delete,
                contentDescription = "Delete item",
                tint = HelixColors.SecondaryInk,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/**
 * Swipeable fact deck, mirroring the iOS `FactCardCarousel`: one fact per page
 * with an "N of M" counter and dot indicators.
 */
@Composable
private fun FactCarousel(facts: List<KnowledgeItem>, onDelete: (String) -> Unit) {
    val pagerState = rememberPagerState(pageCount = { facts.size })

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth().height(168.dp),
        ) { page ->
            val fact = facts[page]
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 2.dp)
                    .background(HelixColors.Background, RoundedCornerShape(12.dp))
                    .border(1.dp, HelixColors.Hairline, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.VerifiedUser,
                        contentDescription = null,
                        tint = HelixColors.Teal,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.size(6.dp))
                    Text(
                        text = "Fact",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = HelixColors.Teal,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = "${page + 1} of ${facts.size}",
                        style = MaterialTheme.typography.labelSmall,
                        color = HelixColors.SecondaryInk,
                    )
                }

                Text(
                    text = fact.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = HelixColors.Ink,
                    modifier = Modifier.weight(1f),
                )

                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = fact.source.ifBlank { "Manual" },
                        style = MaterialTheme.typography.labelSmall,
                        color = HelixColors.SecondaryInk,
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { onDelete(fact.id) }) {
                        Icon(
                            Icons.Filled.Delete,
                            contentDescription = "Delete fact",
                            tint = HelixColors.SecondaryInk,
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
                            if (index == pagerState.currentPage) HelixColors.Teal else HelixColors.Hairline,
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
    KnowledgeBucket.PROJECTS -> Icons.Filled.Folder
    KnowledgeBucket.FACTS -> Icons.Filled.VerifiedUser
    KnowledgeBucket.MEMORIES -> Icons.Filled.Psychology
    KnowledgeBucket.TODOS -> Icons.Filled.Checklist
}

private fun bucketSummary(bucket: KnowledgeBucket, count: Int): String = when (bucket) {
    KnowledgeBucket.PROJECTS -> "$count projects"
    KnowledgeBucket.FACTS -> "$count facts available for RAG"
    KnowledgeBucket.MEMORIES -> "$count conversation memories"
    KnowledgeBucket.TODOS -> "$count follow-up items"
}
