// Sessions tab: lazy list of saved sessions as LinenCards, swipe left to
// delete. Port of ios/Runner/NativeSessionsView.swift.
package com.artjiang.helix.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.R
import com.artjiang.helix.core.SessionSummary
import kotlinx.coroutines.launch

@Composable
fun SessionsScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    val sessions by bridge.sessions.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = HelixSpacing.screen,
            end = HelixSpacing.screen,
            top = HelixSpacing.s4,
            bottom = HelixSpacing.s24,
        ),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.cardGap),
    ) {
        // Counts are noise over an empty list; only summarize real history.
        if (sessions.isNotEmpty()) {
            item(key = "summary") {
                Column(verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
                    Text(
                        text = "${sessions.size} saved sessions",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                    TagRow(
                        values = listOf(
                            "${sessions.sumOf { it.answerCount }} answers",
                            "${sessions.sumOf { it.transcriptTurns.size }} transcript turns",
                            "Swipe left to delete",
                        ),
                    )
                }
            }
        }

        if (sessions.isEmpty()) {
            item(key = "empty") {
                LinenCard {
                    EmptyState(
                        title = "No saved sessions",
                        detail = "Ask a question in Assistant, then save the session to build history.",
                        icon = Icons.Outlined.History,
                        illustration = painterResource(R.drawable.helix_empty_sessions),
                    )
                }
            }
        } else {
            items(sessions, key = { it.id }) { session ->
                SessionCard(
                    session = session,
                    onDelete = { scope.launch { bridge.sessionRepository.remove(session.id) } },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SessionCard(session: SessionSummary, onDelete: () -> Unit) {
    val tokens = HelixTheme.tokens
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else {
                false
            }
        },
        positionalThreshold = { distance -> distance * 0.45f },
    )
    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(tokens.dangerTint, MaterialTheme.shapes.large)
                    .padding(horizontal = HelixSpacing.s20),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(
                    Icons.Outlined.Delete,
                    contentDescription = "Delete session",
                    tint = tokens.onDangerTint,
                )
            }
        },
    ) {
        LinenCard(leftRule = tokens.accent) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            ) {
                Text(
                    text = session.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = tokens.ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                StatusPill(text = relativeLabel(session.createdAtMillis), tint = tokens.inkSecondary)
            }
            Text(
                text = session.answerPreview.ifBlank {
                    session.transcriptTurns.firstOrNull().orEmpty()
                },
                style = MaterialTheme.typography.bodyMedium,
                color = tokens.inkSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
            ) {
                Icon(
                    Icons.Outlined.History,
                    contentDescription = null,
                    tint = tokens.inkMuted,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    text = "${session.answerCount} answers · ${session.transcriptTurns.size} turns",
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.inkMuted,
                )
                Spacer(Modifier.weight(1f))
            }
        }
    }
}
