package com.artjiang.helix.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.OutlinedTextField
import androidx.compose.ui.Alignment
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.conversate.ConversateIntent
import com.artjiang.helix.conversate.ConversatePrefs
import com.artjiang.helix.conversate.HelixMode
import com.artjiang.helix.ring.RingLinkState

/** Assistant-tab control surface for Conversate (spec §5.5). */
@Composable
fun ConversateCard(bridge: HelixBridge) {
    val enabled by bridge.conversateEnabled.collectAsStateWithLifecycle()
    val live by bridge.conversate.isLive.collectAsStateWithLifecycle()
    val preview by bridge.conversate.hudPreview.collectAsStateWithLifecycle()
    val failures by bridge.conversate.cueFailures.collectAsStateWithLifecycle()
    val notes by bridge.prepNoteRepository.notes.collectAsStateWithLifecycle()
    var selectedNoteId by remember { mutableStateOf<String?>(null) }
    var pickerOpen by remember { mutableStateOf(false) }
    var editorOpen by remember { mutableStateOf(false) }
    val paused by bridge.conversate.paused.collectAsStateWithLifecycle()
    val mode by bridge.helixMode.collectAsStateWithLifecycle()
    val prefs by bridge.conversatePrefs.collectAsStateWithLifecycle()

    HelixSection(title = "Conversate", subtitle = "Live captions and AI cues on your glasses") {
        ToggleRow(
            title = "Conversate mode",
            checked = enabled,
            detail = "Hold the left pad for the menu. Double-tap goes back.",
            onCheckedChange = bridge::setConversateEnabled,
        )
        if (!enabled) return@HelixSection
        Text("Mode", style = MaterialTheme.typography.labelMedium)
        HelixSegmentedRow(
            entries = HelixMode.entries,
            selected = mode,
            label = ::helixModeTitle,
            onSelect = bridge::setHelixMode,
        )
        if (mode == HelixMode.DISPLAY_ONLY) {
            Text(
                "No microphone. The glasses show dashboards, reminders and answers to questions you type below.",
                style = MaterialTheme.typography.bodySmall,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
            TextButton(onClick = { pickerOpen = true }) {
                Text("Prep note: " + (notes.firstOrNull { it.id == selectedNoteId }?.title ?: "None"))
            }
            DropdownMenu(expanded = pickerOpen, onDismissRequest = { pickerOpen = false }) {
                DropdownMenuItem(text = { Text("None") }, onClick = { selectedNoteId = null; pickerOpen = false })
                notes.forEach { n ->
                    DropdownMenuItem(text = { Text(n.title) }, onClick = { selectedNoteId = n.id; pickerOpen = false })
                }
            }
            TextButton(onClick = { editorOpen = true }) { Text("Manage") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
            if (!live) {
                Button(
                    onClick = { bridge.startConversate(selectedNoteId) },
                    enabled = mode != HelixMode.DISPLAY_ONLY,
                ) { Text("Start") }
            } else {
                OutlinedButton(onClick = { bridge.conversate.setPaused(!paused) }) {
                    Text(if (paused) "Resume" else "Pause")
                }
                Button(onClick = { bridge.endConversate() }) { Text("End") }
                TextButton(onClick = { bridge.conversate.intent(ConversateIntent.MENU) }) { Text("Menu") }
            }
        }
        if (failures >= 3) {
            Text("Cues unavailable - check your AI provider key.", color = MaterialTheme.colorScheme.error)
        }
        if (preview.isNotEmpty()) {
            LinenCard(modifier = Modifier.fillMaxWidth()) {
                Text(preview, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
            }
        }
        AskBox(bridge)
        SliderRow(
            title = "Caption lines",
            value = prefs.captionLines,
            range = ConversatePrefs.CAPTION_LINE_RANGE,
            onCommit = bridge::setConversateCaptionLines,
        )
        SliderRow(
            title = "Glasses brightness",
            value = prefs.brightness,
            range = ConversatePrefs.BRIGHTNESS_RANGE,
            onCommit = bridge::setConversateBrightness,
        )
    }
    if (enabled) RingSection(bridge)
    if (editorOpen) PrepNotesSheet(bridge, onDismiss = { editorOpen = false })
}

/** "Ask ChatGPT" through the Helix relay; the answer streams here and lands on the lens. */
@Composable
private fun AskBox(bridge: HelixBridge) {
    val state by bridge.askState.collectAsStateWithLifecycle()
    var question by remember { mutableStateOf("") }
    var deep by remember { mutableStateOf(false) }
    OutlinedTextField(
        value = question,
        onValueChange = { question = it },
        label = { Text("Ask ChatGPT") },
        modifier = Modifier.fillMaxWidth(),
        trailingIcon = {
            TextButton(
                onClick = { bridge.askRelay(question, deep); question = "" },
                enabled = question.isNotBlank(),
            ) { Text("Ask") }
        },
    )
    Row(verticalAlignment = Alignment.CenterVertically) {
        Checkbox(checked = deep, onCheckedChange = { deep = it })
        Text("Think deeper", style = MaterialTheme.typography.bodySmall)
    }
    if (state.question.isNotEmpty()) {
        LinenCard(modifier = Modifier.fillMaxWidth()) {
            Text(state.question, style = MaterialTheme.typography.labelMedium)
            val body = state.error ?: state.answer.ifEmpty { if (state.streaming) "..." else "" }
            Text(body, style = MaterialTheme.typography.bodySmall)
        }
    }
}

internal fun helixModeTitle(mode: HelixMode): String = when (mode) {
    HelixMode.PHONE_MIC -> "Phone mic"
    HelixMode.OMI -> "Omi"
    HelixMode.DISPLAY_ONLY -> "Display only"
}

/** R1 ring controller (Plan B): opt-in, status, last gesture for hardware checks. */
@Composable
private fun RingSection(bridge: HelixBridge) {
    val ringOn by bridge.ringEnabled.collectAsStateWithLifecycle()
    val state by bridge.ringState.collectAsStateWithLifecycle()
    val name by bridge.ringName.collectAsStateWithLifecycle()
    val last by bridge.ringLastGesture.collectAsStateWithLifecycle()
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { bridge.reconnectRing() }
    HelixSection(title = "R1 ring", subtitle = "Tap select · double-tap back · hold menu · swipe scroll") {
        ToggleRow(
            title = "Use R1 ring",
            checked = ringOn,
            detail = "Set the ring up in the Even app once, then force-stop the Even app so Helix can connect.",
            onCheckedChange = bridge::setRingEnabled,
        )
        if (ringOn) {
            val status = when (state) {
                RingLinkState.OFF -> "Off"
                RingLinkState.CONNECTING -> "Connecting${name?.let { " to $it" } ?: ""}..."
                RingLinkState.CONNECTED -> "Connected${name?.let { ": $it" } ?: ""}"
                RingLinkState.NOT_FOUND -> "No paired R1 ring found. Pair it in the Even app first, then force-stop the Even app."
                RingLinkState.NO_PERMISSION -> "Bluetooth permission needed."
            }
            Text(status, style = MaterialTheme.typography.bodySmall)
            if (last.isNotEmpty()) Text("Last gesture: $last", style = MaterialTheme.typography.bodySmall)
            if (state == RingLinkState.NO_PERMISSION) {
                OutlinedButton(onClick = { permissionLauncher.launch(bridge.bluetooth.requiredPermissions()) }) {
                    Text("Grant Bluetooth permission")
                }
            } else {
                OutlinedButton(onClick = { bridge.reconnectRing() }) { Text("Reconnect ring") }
            }
        }
    }
}

