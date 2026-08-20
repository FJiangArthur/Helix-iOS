// Port of ios/Runner/NativeHelixAssistantView.swift.
package com.artjiang.helix.ui

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.RemoveRedEye
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.ai.ConversationEvent
import com.artjiang.helix.core.ConversationMode

@Composable
fun AssistantScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val settings by bridge.settings.collectAsStateWithLifecycle()
    val isListening by bridge.isListening.collectAsStateWithLifecycle()
    val isAnswering by bridge.isAnswering.collectAsStateWithLifecycle()
    val partial by bridge.partialTranscript.collectAsStateWithLifecycle()
    val transcript by bridge.transcriptText.collectAsStateWithLifecycle()
    val lastTurn by bridge.lastTurn.collectAsStateWithLifecycle()
    val speechError by bridge.speechError.collectAsStateWithLifecycle()
    val eventLog by bridge.eventLog.collectAsStateWithLifecycle()
    val effectiveProvider by bridge.effectiveProvider.collectAsStateWithLifecycle()
    val hudPages by bridge.hudPages.collectAsStateWithLifecycle()
    val hudIndex by bridge.hudPageIndex.collectAsStateWithLifecycle()

    var draft by remember { mutableStateOf("") }

    val micPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> if (granted) bridge.startListening() }

    val answerText = lastTurn?.answer?.text.orEmpty()
    val questionText = lastTurn?.question?.text.orEmpty()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HelixSection(title = "Assistant", subtitle = modeSummary(settings.mode)) {
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                ConversationMode.entries.forEachIndexed { index, mode ->
                    SegmentedButton(
                        selected = settings.mode == mode,
                        onClick = { bridge.setMode(mode) },
                        shape = SegmentedButtonDefaults.itemShape(index, ConversationMode.entries.size),
                    ) {
                        Text(modeTitle(mode))
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatusPill(
                    text = when {
                        isAnswering -> "Answering..."
                        isListening -> "Listening"
                        else -> "Idle"
                    },
                    tint = if (isListening) HelixColors.Teal else HelixColors.SecondaryInk,
                )
                Spacer(Modifier.weight(1f))

                FilledTonalIconButton(
                    onClick = {
                        if (isListening) {
                            bridge.stopListening()
                        } else {
                            micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    },
                ) {
                    Icon(
                        imageVector = if (isListening) Icons.Filled.Stop else Icons.Filled.Mic,
                        contentDescription = if (isListening) "Stop listening" else "Start listening",
                    )
                }

                FilledTonalIconButton(
                    onClick = { bridge.presentToGlasses(answerText) },
                    enabled = answerText.isNotEmpty(),
                ) {
                    Icon(Icons.Filled.RemoveRedEye, contentDescription = "Send answer to glasses")
                }

                FilledTonalIconButton(
                    onClick = bridge::saveCurrentSession,
                    enabled = answerText.isNotEmpty() || questionText.isNotEmpty(),
                ) {
                    Icon(Icons.Filled.Download, contentDescription = "Save session")
                }
            }

            if (speechError.isNotBlank()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = speechError,
                        style = MaterialTheme.typography.bodySmall,
                        color = HelixColors.Amber,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = bridge::clearSpeechError) {
                        Icon(Icons.Filled.Close, contentDescription = "Dismiss error", tint = HelixColors.Amber)
                    }
                }
            }

            if (isListening && partial.isNotBlank()) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(
                        Icons.Filled.GraphicEq,
                        contentDescription = null,
                        tint = HelixColors.Teal,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(partial, style = MaterialTheme.typography.bodySmall, color = HelixColors.SecondaryInk)
                }
            }

            TagRow(
                values = listOf(
                    "${effectiveProvider.displayName} - ${activeModel(settings, effectiveProvider.name)}",
                    if (settings.bitmapHud) "Bitmap HUD" else "Text HUD",
                    if (hudPages.isEmpty()) "No HUD page" else "Page ${hudIndex + 1} of ${hudPages.size}",
                ),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text("Ask or paste a question") },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                )
                FilledTonalIconButton(
                    onClick = {
                        bridge.askQuestion(draft)
                        draft = ""
                    },
                    enabled = draft.isNotBlank() && !isAnswering,
                ) {
                    Icon(Icons.Filled.ArrowUpward, contentDescription = "Ask Helix")
                }
            }

            HairlineDivider()
            WorkspaceRow(
                title = "Answer",
                value = answerText,
                emptyValue = "Answers appear here before being sent to the G1 HUD.",
                icon = Icons.Filled.AutoAwesome,
                tint = HelixColors.Green,
            )
            HairlineDivider()
            WorkspaceRow(
                title = "Detected question",
                value = questionText,
                emptyValue = "Ask manually or start a listening run.",
                icon = Icons.Filled.QuestionAnswer,
                tint = HelixColors.Indigo,
            )
            HairlineDivider()
            WorkspaceRow(
                title = "Transcript",
                value = transcript,
                emptyValue = "No finalized transcript yet.",
                icon = Icons.Filled.GraphicEq,
                tint = HelixColors.Teal,
            )

            val recent = eventLog.takeLast(5).reversed()
            if (recent.isNotEmpty()) {
                HairlineDivider()
                Text(
                    text = "Recent activity",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = HelixColors.Ink,
                )
                recent.forEach { event -> ActivityRow(event) }
            }
        }
    }
}

@Composable
private fun ActivityRow(event: ConversationEvent) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = eventTitle(event),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = HelixColors.Ink,
            )
            Text(
                text = eventDetail(event),
                style = MaterialTheme.typography.bodySmall,
                color = HelixColors.SecondaryInk,
            )
        }
        Text(
            text = relativeLabel(event.timestampMillis),
            style = MaterialTheme.typography.labelSmall,
            color = HelixColors.SecondaryInk,
        )
    }
}

private fun eventTitle(event: ConversationEvent): String = when (event) {
    is ConversationEvent.TranscriptReceived -> "Transcript finalized"
    is ConversationEvent.QuestionDetected -> "Question detected"
    is ConversationEvent.AnswerStarted -> "Answer started"
    is ConversationEvent.AnswerCompleted -> "Answer completed"
    is ConversationEvent.Suppressed -> "Suppressed"
    is ConversationEvent.Failed -> "Runtime failure"
    is ConversationEvent.SettingsUpdated -> "Settings updated"
}

private fun eventDetail(event: ConversationEvent): String = when (event) {
    is ConversationEvent.TranscriptReceived -> event.text
    is ConversationEvent.QuestionDetected -> event.question.text
    is ConversationEvent.AnswerStarted -> event.question.text
    is ConversationEvent.AnswerCompleted -> "${event.answer.model} - ${event.latencyMillis} ms"
    is ConversationEvent.Suppressed -> "${event.reason.name.lowercase().replace('_', ' ')}: ${event.detail}"
    is ConversationEvent.Failed -> event.error.message ?: "Unknown error"
    is ConversationEvent.SettingsUpdated -> modeTitle(event.settings.mode)
}

internal fun modeTitle(mode: ConversationMode): String = when (mode) {
    ConversationMode.GENERAL -> "General"
    ConversationMode.INTERVIEW -> "Interview"
    ConversationMode.PASSIVE -> "Passive"
}

internal fun modeSummary(mode: ConversationMode): String = when (mode) {
    ConversationMode.GENERAL -> "Concise answers for live conversation."
    ConversationMode.INTERVIEW -> "Speakable answers with STAR framing."
    ConversationMode.PASSIVE -> "Quiet correction and context reminders."
}

internal fun activeModel(
    settings: com.artjiang.helix.core.HelixSettings,
    providerKind: String,
): String = settings.providers[providerKind]?.smartModel ?: "built-in"
