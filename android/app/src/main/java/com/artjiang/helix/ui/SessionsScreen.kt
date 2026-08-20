// Port of ios/Runner/NativeSessionsView.swift.
package com.artjiang.helix.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import kotlinx.coroutines.launch

@Composable
fun SessionsScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val sessions by bridge.sessions.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HelixSection(
            title = "Session archive",
            subtitle = "${sessions.size} saved sessions",
        ) {
            TagRow(
                values = listOf(
                    "${sessions.sumOf { it.answerCount }} answers",
                    "${sessions.sumOf { it.transcriptTurns.size }} transcript turns",
                ),
            )
            HairlineDivider()

            if (sessions.isEmpty()) {
                EmptyState(
                    title = "No saved sessions",
                    detail = "Ask a question in Assistant, then save the session to build history.",
                    icon = Icons.Filled.History,
                )
            } else {
                sessions.forEachIndexed { index, session ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(
                            Icons.Filled.History,
                            contentDescription = null,
                            tint = HelixColors.Teal,
                            modifier = Modifier.size(20.dp),
                        )
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(
                                text = session.title,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = HelixColors.Ink,
                                maxLines = 1,
                            )
                            Text(
                                text = session.answerPreview.ifBlank {
                                    session.transcriptTurns.firstOrNull().orEmpty()
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = HelixColors.SecondaryInk,
                                maxLines = 2,
                            )
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(
                                text = relativeLabel(session.createdAtMillis),
                                style = MaterialTheme.typography.labelSmall,
                                color = HelixColors.SecondaryInk,
                            )
                            IconButton(onClick = { scope.launch { bridge.sessionRepository.remove(session.id) } }) {
                                Icon(
                                    Icons.Filled.Delete,
                                    contentDescription = "Delete session",
                                    tint = HelixColors.SecondaryInk,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }
                    if (index < sessions.size - 1) HairlineDivider()
                }
            }
        }
    }
}
