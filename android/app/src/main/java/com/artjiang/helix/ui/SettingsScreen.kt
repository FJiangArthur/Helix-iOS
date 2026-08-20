// Port of ios/Runner/NativeSettingsView.swift.
package com.artjiang.helix.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind

@Composable
fun SettingsScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val settings by bridge.settings.collectAsStateWithLifecycle()
    val effectiveProvider by bridge.effectiveProvider.collectAsStateWithLifecycle()
    // Encrypted prefs are not a Flow, so key presence is read imperatively;
    // this revision counter is what makes the rows recompose after a save.
    val keyRevision by bridge.settingsRepository.keyRevision.collectAsStateWithLifecycle()

    var keyDialogKind by remember { mutableStateOf<String?>(null) }
    var showSkillDialog by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HelixSection(
            title = "Conversation",
            subtitle = "Answers via ${effectiveProvider.displayName}",
        ) {
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

            SettingToggle(
                title = "Auto-detect",
                detail = "Identify questions in live transcripts.",
                checked = settings.autoDetectQuestions,
            ) { value -> bridge.updateSettings { it.copy(autoDetectQuestions = value) } }
            HairlineDivider()
            SettingToggle(
                title = "Auto-answer",
                detail = "Generate a response when Helix detects intent.",
                checked = settings.autoAnswer,
            ) { value -> bridge.updateSettings { it.copy(autoAnswer = value) } }
            HairlineDivider()
            SettingToggle(
                title = "Fact-check",
                detail = "Verify answers in the background.",
                checked = settings.factCheck,
            ) { value -> bridge.updateSettings { it.copy(factCheck = value) } }
            HairlineDivider()
            SettingToggle(
                title = "Real-time insights",
                detail = "Proactive context while you talk (experimental).",
                checked = settings.insightsEnabled,
            ) { value -> bridge.updateSettings { it.copy(insightsEnabled = value) } }
            HairlineDivider()
            SettingToggle(
                title = "Bitmap HUD",
                detail = "Render G1 pages as bitmap frames.",
                checked = settings.bitmapHud,
            ) { value -> bridge.updateSettings { it.copy(bitmapHud = value) } }

            Column(modifier = Modifier.fillMaxWidth()) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Max response sentences",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = HelixColors.SecondaryInk,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = "${settings.maxResponseSentences}",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = HelixColors.Ink,
                    )
                }
                Slider(
                    value = settings.maxResponseSentences.toFloat(),
                    onValueChange = { value ->
                        bridge.updateSettings { it.copy(maxResponseSentences = value.toInt().coerceIn(1, 10)) }
                    },
                    valueRange = 1f..10f,
                    steps = 8,
                )
            }
        }

        HelixSection(title = "Assistant skill", subtitle = settings.activeSkill.name) {
            Text(
                text = settings.activeSkill.prompt,
                style = MaterialTheme.typography.bodySmall,
                color = HelixColors.SecondaryInk,
            )
            OutlinedButton(onClick = { showSkillDialog = true }) { Text("Edit skill") }
        }

        HelixSection(title = "AI providers", subtitle = "Tap a provider to set its API key") {
            HelixSettings.defaultProviders().keys.forEachIndexed { index, kind ->
                val config = settings.providers[kind]
                val hasKey = remember(kind, keyRevision) { bridge.hasApiKey(kind) }
                ProviderRow(
                    name = ProviderKind.entries.firstOrNull { it.name == kind }?.displayName ?: kind,
                    model = config?.smartModel.orEmpty(),
                    hasKey = hasKey,
                    isSelected = settings.activeProvider == kind,
                    // Fix of an iOS bug: the row shows what will ACTUALLY answer.
                    // A selected provider with no key falls back to the
                    // deterministic provider, and now says so.
                    effectiveNote = if (settings.activeProvider == kind && !hasKey) {
                        "Deterministic (no key)"
                    } else {
                        null
                    },
                    onClick = { keyDialogKind = kind },
                )
                if (index < HelixSettings.defaultProviders().size - 1) HairlineDivider(indent = 22)
            }
        }
    }

    keyDialogKind?.let { kind ->
        ProviderKeyDialog(
            bridge = bridge,
            kind = kind,
            settings = settings,
            hasKey = remember(kind, keyRevision) { bridge.hasApiKey(kind) },
            onDismiss = { keyDialogKind = null },
        )
    }

    if (showSkillDialog) {
        SkillDialog(
            skill = settings.activeSkill,
            onDismiss = { showSkillDialog = false },
            onSave = { skill ->
                bridge.updateSettings { it.copy(activeSkill = skill) }
                showSkillDialog = false
            },
        )
    }
}

@Composable
private fun SettingToggle(
    title: String,
    detail: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = HelixColors.Ink,
            )
            Text(text = detail, style = MaterialTheme.typography.bodySmall, color = HelixColors.SecondaryInk)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun ProviderRow(
    name: String,
    model: String,
    hasKey: Boolean,
    isSelected: Boolean,
    effectiveNote: String?,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(if (hasKey) HelixColors.Green else HelixColors.Amber, CircleShape),
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = HelixColors.Ink,
                )
                if (isSelected) {
                    Spacer(Modifier.size(6.dp))
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "Selected for answers",
                        tint = HelixColors.Green,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
            Text(
                text = effectiveNote ?: model,
                style = MaterialTheme.typography.labelSmall,
                color = if (effectiveNote != null) HelixColors.Amber else HelixColors.SecondaryInk,
            )
        }
        Text(
            text = if (hasKey) "Key set" else "Needs key",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = if (hasKey) HelixColors.Green else HelixColors.Amber,
        )
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = HelixColors.SecondaryInk,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun ProviderKeyDialog(
    bridge: HelixBridge,
    kind: String,
    settings: HelixSettings,
    hasKey: Boolean,
    onDismiss: () -> Unit,
) {
    val config = settings.providers[kind]
    val displayName = ProviderKind.entries.firstOrNull { it.name == kind }?.displayName ?: kind

    var apiKey by remember { mutableStateOf("") }
    var smartModel by remember { mutableStateOf(config?.smartModel.orEmpty()) }
    var lightModel by remember { mutableStateOf(config?.lightModel.orEmpty()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(displayName) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    label = { Text(if (hasKey) "Replace stored key" else "API key") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = smartModel,
                    onValueChange = { smartModel = it },
                    label = { Text("Smart model") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = lightModel,
                    onValueChange = { lightModel = it },
                    label = { Text("Light model") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (settings.activeProvider == kind) {
                    Text(
                        text = if (hasKey) {
                            "Active provider for answers."
                        } else {
                            "Selected, but with no key stored Helix answers with the built-in deterministic provider."
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = if (hasKey) HelixColors.Green else HelixColors.Amber,
                    )
                } else {
                    TextButton(
                        onClick = {
                            saveProvider(bridge, kind, apiKey, smartModel, lightModel)
                            bridge.updateSettings { it.copy(activeProvider = kind) }
                            onDismiss()
                        },
                    ) {
                        Text("Use $displayName for answers")
                    }
                }
                if (hasKey) {
                    TextButton(
                        onClick = {
                            bridge.setApiKey(kind, null)
                            onDismiss()
                        },
                    ) {
                        Text("Remove stored key", color = HelixColors.Amber)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    saveProvider(bridge, kind, apiKey, smartModel, lightModel)
                    onDismiss()
                },
            ) {
                Text("Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

private fun saveProvider(
    bridge: HelixBridge,
    kind: String,
    apiKey: String,
    smartModel: String,
    lightModel: String,
) {
    if (apiKey.isNotBlank()) bridge.setApiKey(kind, apiKey)
    bridge.updateSettings { current ->
        val existing = current.providers[kind] ?: return@updateSettings current
        current.copy(
            providers = current.providers + (
                kind to existing.copy(
                    smartModel = smartModel.ifBlank { existing.smartModel },
                    lightModel = lightModel.ifBlank { existing.lightModel },
                )
                ),
        )
    }
}

@Composable
private fun SkillDialog(
    skill: ActiveSkill,
    onDismiss: () -> Unit,
    onSave: (ActiveSkill) -> Unit,
) {
    var name by remember { mutableStateOf(skill.name) }
    var prompt by remember { mutableStateOf(skill.prompt) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Assistant skill") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = prompt,
                    onValueChange = { prompt = it },
                    label = { Text("System prompt") },
                    maxLines = 6,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onSave(ActiveSkill(name = name.trim(), prompt = prompt.trim())) },
                enabled = name.isNotBlank() && prompt.isNotBlank(),
            ) {
                Text("Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
