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
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Key
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material3.IconButton
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.BuiltInSkills
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.ai.ModelRole
import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.data.OmiImportService
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.TranscriptionSource

@Composable
fun SettingsScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    val settings by bridge.settings.collectAsStateWithLifecycle()
    val effectiveProvider by bridge.effectiveProvider.collectAsStateWithLifecycle()
    // Encrypted prefs are not a Flow, so key presence is read imperatively;
    // this revision counter is what makes the rows recompose after a save.
    val keyRevision by bridge.settingsRepository.keyRevision.collectAsStateWithLifecycle()
    val keyCheck by bridge.keyCheck.collectAsStateWithLifecycle()

    var keyDialogKind by remember { mutableStateOf<String?>(null) }
    var skillEditor by remember { mutableStateOf<SkillEditorTarget?>(null) }
    var showOmiDialog by remember { mutableStateOf(false) }
    var showOmiRelayDialog by remember { mutableStateOf(false) }
    val omiLiveActive by bridge.isOmiLiveActive.collectAsStateWithLifecycle()
    val omiLiveError by bridge.omiLiveError.collectAsStateWithLifecycle()
    val omiLastSegment by bridge.omiLastSegment.collectAsStateWithLifecycle()
    val omiHasRelay = remember(keyRevision) { bridge.hasApiKey(HelixBridge.OMI_RELAY_KEY_KIND) }
    val transcriptionSource by bridge.transcriptionSource.collectAsStateWithLifecycle()
    val questionMode by bridge.questionMode.collectAsStateWithLifecycle()
    val questionSensitivity by bridge.questionSensitivity.collectAsStateWithLifecycle()
    val storedTranscriptionModel by bridge.openAiTranscriptionModel.collectAsStateWithLifecycle()
    var transcriptionModelDraft by remember(storedTranscriptionModel) { mutableStateOf(storedTranscriptionModel) }
    val catalogForPicker by bridge.catalog.collectAsStateWithLifecycle()

    val omiImportState by bridge.omiImportState.collectAsStateWithLifecycle()
    val omiLastImport by bridge.omiLastImportMillis.collectAsStateWithLifecycle()
    val omiHasKey = remember(keyRevision) { bridge.hasApiKey(OmiImportService.KEY_KIND) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = HelixSpacing.screen)
            .padding(top = HelixSpacing.s4, bottom = HelixSpacing.s24),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.cardGap),
    ) {
        HelixSection(
            title = "Conversation",
            subtitle = "Answers via ${effectiveProvider.displayName}",
            icon = Icons.Outlined.Forum,
            tint = tokens.accent,
        ) {
            HelixSegmentedRow(
                entries = ConversationMode.entries,
                selected = settings.mode,
                label = ::modeTitle,
            ) { mode -> bridge.setMode(mode) }

            ToggleRow(
                title = "Auto-detect",
                detail = "Identify questions in live transcripts.",
                checked = settings.autoDetectQuestions,
            ) { value -> bridge.updateSettings { it.copy(autoDetectQuestions = value) } }
            HairlineDivider()
            ToggleRow(
                title = "Auto-answer",
                detail = "Generate a response when Helix detects intent.",
                checked = settings.autoAnswer,
            ) { value -> bridge.updateSettings { it.copy(autoAnswer = value) } }
            // The Real-time insights toggle is HIDDEN, not removed: on Android
            // `insightsEnabled` controls nothing (the iOS InsightCoordinator
            // has no port yet), and a visible no-op switch is worse than none.
            // The HelixSettings field stays for iOS JSON parity — restore the
            // ToggleRow when the insight pipeline lands (roadmap item).
            // No Fact-check or Bitmap HUD toggles either: the Android v1 port
            // has no fact-check pipeline and renders the text HUD path only,
            // so those settings (kept in HelixSettings for iOS parity) control
            // nothing.

            SliderRow(
                title = "Max response sentences",
                value = settings.maxResponseSentences,
                range = 1..10,
            ) { value -> bridge.updateSettings { it.copy(maxResponseSentences = value) } }
        }

        ConversateSettingsSection(bridge)

        // Port of the iOS active-skill picker + custom-skill sheet
        // (NativeSettingsView.swift): six built-ins plus the user's custom
        // skills, tap to activate, with add/edit/delete for customs.
        val resolvedSkill = settings.resolvedSkill()
        HelixSection(
            title = "Assistant skill",
            subtitle = resolvedSkill.label,
            icon = Icons.Outlined.AutoAwesome,
            tint = tokens.gold,
        ) {
            val selectableSkills = settings.selectableSkills()
            selectableSkills.forEachIndexed { index, skill ->
                SkillRow(
                    skill = skill,
                    isSelected = skill.value == resolvedSkill.value,
                    onSelect = { bridge.updateSettings { it.copy(activeSkillID = skill.value) } },
                    onEdit = if (skill.isBuiltIn) null else ({ skillEditor = SkillEditorTarget.Edit(skill) }),
                )
                if (index < selectableSkills.size - 1) HairlineDivider(indent = 28)
            }
            HairlineDivider()
            Text(
                text = resolvedSkill.prompt,
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
            OutlinedButton(
                onClick = { skillEditor = SkillEditorTarget.New },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = tokens.accentDeep),
            ) { Text("New custom skill") }
        }

        HelixSection(
            title = "AI providers",
            subtitle = "Tap a provider to set its API key",
            icon = Icons.Outlined.Key,
            tint = tokens.support,
        ) {
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
                when (val verdict = keyCheck[kind]) {
                    is HelixBridge.KeyCheckState.Valid -> Text(
                        text = "Key OK · ${verdict.chatModelCount} chat models",
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.success,
                        modifier = Modifier.padding(start = 20.dp),
                    )

                    is HelixBridge.KeyCheckState.Invalid -> DismissibleError(
                        text = verdict.message,
                        onDismiss = { bridge.dismissKeyCheck(kind) },
                    )

                    is HelixBridge.KeyCheckState.Failed -> Text(
                        text = "Couldn't verify key: ${verdict.message}",
                        style = MaterialTheme.typography.labelSmall,
                        color = HelixTheme.tokens.warning,
                        modifier = Modifier.padding(start = 20.dp),
                    )

                    is HelixBridge.KeyCheckState.Unsupported -> Text(
                        text = verdict.message,
                        style = MaterialTheme.typography.labelSmall,
                        color = onTintColor(tokens.warning),
                        modifier = Modifier.padding(start = 20.dp),
                    )

                    else -> Unit
                }
                if (index < HelixSettings.defaultProviders().size - 1) HairlineDivider(indent = 22)
            }
        }

        HelixSection(
            title = "Transcription",
            subtitle = sourceSummary(transcriptionSource),
            icon = Icons.Outlined.GraphicEq,
            tint = tokens.accent,
        ) {
            // Short labels: "OpenAI Realtime" wraps inside a three-way segmented row.
            HelixSegmentedRow(
                entries = TranscriptionSource.entries,
                selected = transcriptionSource,
                label = ::sourceShortTitle,
            ) { source -> bridge.setTranscriptionSource(source) }
            when (transcriptionSource) {
                TranscriptionSource.OPENAI_REALTIME -> {
                    val openAiHasKey = remember(keyRevision) { bridge.hasApiKey(ProviderKind.OPENAI.name) }
                    if (!openAiHasKey) {
                        Text(
                            text = "Needs an OpenAI key — set it under AI providers.",
                            style = MaterialTheme.typography.bodySmall,
                            color = onTintColor(tokens.warning),
                        )
                    }
                    ModelPickerField(
                        value = transcriptionModelDraft,
                        onValueChange = {
                            transcriptionModelDraft = it
                            bridge.setOpenAiTranscriptionModel(it)
                        },
                        options = bridge.modelOptions(
                            ProviderKind.OPENAI.name,
                            ModelRole.TRANSCRIPTION,
                            pinned = transcriptionModelDraft,
                        ),
                        label = "Transcription model",
                        onRefresh = if (openAiHasKey) ({ bridge.refreshModels(ProviderKind.OPENAI.name, force = true) }) else null,
                    )
                    Text(
                        text = "Streams microphone audio to OpenAI continuously while listening (billed per minute, including silence).",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                }

                TranscriptionSource.OMI -> if (!omiHasRelay) {
                    Text(
                        text = "Needs the relay URL — set it under Omi connection.",
                        style = MaterialTheme.typography.bodySmall,
                        color = onTintColor(tokens.warning),
                    )
                }

                TranscriptionSource.DEVICE -> Unit
            }
            HairlineDivider()
            Text(
                text = "Question mode",
                style = MaterialTheme.typography.titleSmall,
                color = tokens.ink,
            )
            HelixSegmentedRow(
                entries = QuestionMode.entries,
                selected = questionMode,
                label = ::questionModeTitle,
            ) { mode -> bridge.setQuestionMode(mode) }
            Text(
                text = questionModeDetail(questionMode) +
                    if (questionMode == QuestionMode.ON_DEMAND) " The Auto-detect toggle above has no effect in this mode." else "",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
            Text(
                text = "Question sensitivity",
                style = MaterialTheme.typography.titleSmall,
                color = tokens.ink,
            )
            HelixSegmentedRow(
                entries = QuestionSensitivity.entries,
                selected = questionSensitivity,
                label = ::questionSensitivityTitle,
            ) { sensitivity -> bridge.setQuestionSensitivity(sensitivity) }
            Text(
                text = questionSensitivityDetail(questionSensitivity),
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
        }

        HelixSection(
            title = "Omi connection",
            subtitle = if (omiHasKey) "Manual import from app.omi.me" else "Connect your Omi account",
            icon = Icons.Outlined.Link,
            tint = tokens.support,
        ) {
            ProviderRow(
                name = "Omi",
                model = omiLastImport?.let { "Last import ${relativeLabel(it)}" } ?: "Not imported yet",
                hasKey = omiHasKey,
                isSelected = false,
                effectiveNote = null,
                onClick = { showOmiDialog = true },
            )
            Button(
                onClick = bridge::importFromOmi,
                enabled = omiHasKey && omiImportState != HelixBridge.OmiImportState.Running,
            ) {
                Text(
                    if (omiImportState == HelixBridge.OmiImportState.Running) "Importing…"
                    else "Import conversations & memories",
                )
            }
            when (val state = omiImportState) {
                is HelixBridge.OmiImportState.Done -> Text(
                    text = "Imported ${state.result.conversationsImported} conversations and " +
                        "${state.result.memoriesImported} memories" +
                        if (state.result.duplicatesSkipped > 0) {
                            " · ${state.result.duplicatesSkipped} already imported"
                        } else {
                            ""
                        },
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.success,
                )

                is HelixBridge.OmiImportState.Failed -> DismissibleError(
                    text = state.message,
                    onDismiss = bridge::dismissOmiImportState,
                )

                else -> Unit
            }

            HairlineDivider()
            ProviderRow(
                name = "Live transcript relay",
                model = when {
                    omiLiveActive -> omiLastSegment?.text?.let { "Live · \"${it.take(40)}\"" } ?: "Live · waiting for speech"
                    omiHasRelay -> "Relay URL set"
                    else -> "Paste the relay /feed URL"
                },
                hasKey = omiHasRelay,
                isSelected = omiLiveActive,
                effectiveNote = null,
                onClick = { showOmiRelayDialog = true },
            )
            Button(
                onClick = { if (omiLiveActive) bridge.stopOmiLive() else bridge.startOmiLive() },
                enabled = omiHasRelay,
            ) {
                Text(if (omiLiveActive) "Stop live transcript" else "Start live transcript → glasses")
            }
            if (omiLiveError.isNotBlank()) {
                DismissibleError(text = omiLiveError, onDismiss = bridge::clearOmiLiveError)
            }
        }
    }

    if (showOmiRelayDialog) {
        OmiRelayDialog(
            bridge = bridge,
            hasUrl = omiHasRelay,
            onDismiss = { showOmiRelayDialog = false },
        )
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

    if (showOmiDialog) {
        OmiKeyDialog(
            bridge = bridge,
            hasKey = omiHasKey,
            onDismiss = { showOmiDialog = false },
        )
    }

    skillEditor?.let { target ->
        val editing = (target as? SkillEditorTarget.Edit)?.skill
        CustomSkillDialog(
            existing = editing,
            onDismiss = { skillEditor = null },
            onSave = { label, prompt ->
                bridge.updateSettings { current ->
                    // Editing keeps the slug stable; a new skill derives it
                    // from the name (iOS sheet behavior), disambiguated so it
                    // can never shadow a built-in or clobber another custom.
                    val slug = editing?.value ?: BuiltInSkills.uniqueSlug(
                        BuiltInSkills.slugify(label),
                        taken = current.customSkills.map { it.value }.toSet(),
                    )
                    val skill = ActiveSkill(value = slug, label = label, prompt = prompt)
                    current.copy(
                        customSkills = current.customSkills.filter { it.value != slug } + skill,
                        activeSkillID = slug,
                    )
                }
                skillEditor = null
            },
            onDelete = editing?.let { skill ->
                {
                    bridge.updateSettings { current ->
                        current.copy(
                            customSkills = current.customSkills.filter { it.value != skill.value },
                            activeSkillID = if (current.activeSkillID == skill.value) {
                                BuiltInSkills.DEFAULT_VALUE
                            } else {
                                current.activeSkillID
                            },
                        )
                    }
                    skillEditor = null
                }
            },
        )
    }
}

/** Which skill the custom-skill dialog is editing: a fresh one or an existing custom. */
private sealed interface SkillEditorTarget {
    data object New : SkillEditorTarget
    data class Edit(val skill: ActiveSkill) : SkillEditorTarget
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
    val tokens = HelixTheme.tokens
    val dot = if (hasKey) tokens.success else tokens.warning
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
                .background(dot, CircleShape),
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.titleSmall,
                    color = tokens.ink,
                )
                if (isSelected) {
                    Spacer(Modifier.size(6.dp))
                    Icon(
                        Icons.Outlined.CheckCircle,
                        contentDescription = "Selected for answers",
                        tint = tokens.success,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
            Text(
                text = effectiveNote ?: model,
                style = MaterialTheme.typography.labelSmall,
                color = if (effectiveNote != null) onTintColor(tokens.warning) else tokens.inkSecondary,
            )
        }
        Text(
            text = if (hasKey) "Key set" else "Needs key",
            style = MaterialTheme.typography.labelMedium,
            color = onTintColor(dot),
        )
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = tokens.inkMuted,
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
    val tokens = HelixTheme.tokens
    val config = settings.providers[kind]
    val displayName = ProviderKind.entries.firstOrNull { it.name == kind }?.displayName ?: kind
    val keyCheck by bridge.keyCheck.collectAsStateWithLifecycle()
    val catalog by bridge.catalog.collectAsStateWithLifecycle()
    val verdict = keyCheck[kind] ?: HelixBridge.KeyCheckState.Idle

    var apiKey by remember { mutableStateOf("") }
    var smartModel by remember { mutableStateOf(config?.smartModel.orEmpty()) }
    var lightModel by remember { mutableStateOf(config?.lightModel.orEmpty()) }

    // Stored key present: refresh the model list (TTL-gated) so the picker
    // shows live ids without the user pressing anything.
    LaunchedEffect(kind, hasKey) { if (hasKey) bridge.refreshModels(kind) }

    val options = remember(catalog, kind, smartModel) {
        bridge.modelOptions(kind, ModelRole.CHAT, pinned = smartModel)
    }
    val lightOptions = remember(catalog, kind, lightModel) {
        bridge.modelOptions(kind, ModelRole.CHAT, pinned = lightModel)
    }
    val liveModels = catalog[kind]?.models
    val notInList = liveModels != null && smartModel.isNotBlank() &&
        liveModels.none { it.id.equals(smartModel.trim(), ignoreCase = true) }
    val lightNotInList = liveModels != null && lightModel.isNotBlank() &&
        liveModels.none { it.id.equals(lightModel.trim(), ignoreCase = true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.extraLarge,
        containerColor = HelixTheme.tokens.surface,
        titleContentColor = HelixTheme.tokens.ink,
        textContentColor = HelixTheme.tokens.ink,
        title = { Text(displayName, style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedTextField(
                        value = apiKey,
                        onValueChange = { apiKey = it },
                        label = { Text(if (hasKey) "Replace stored key" else "API key") },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        shape = MaterialTheme.shapes.medium,
                        modifier = Modifier.weight(1f),
                    )
                    OutlinedButton(
                        onClick = { bridge.checkApiKey(kind, candidate = apiKey.ifBlank { null }) },
                        enabled = (apiKey.isNotBlank() || hasKey) && verdict != HelixBridge.KeyCheckState.Checking,
                    ) {
                        Text("Check")
                    }
                }
                KeyCheckStatusRow(verdict = verdict, hasKey = hasKey)
                ModelPickerField(
                    value = smartModel,
                    onValueChange = { smartModel = it },
                    options = options,
                    label = "Smart model (manual asks)",
                    isLoading = verdict == HelixBridge.KeyCheckState.Checking,
                    onRefresh = if (hasKey) ({ bridge.refreshModels(kind, force = true) }) else null,
                    supportingText = if (notInList) "Not in $displayName's list" else null,
                )
                Text(
                    text = "Used for questions you ask directly — can take a moment to think.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
                ModelPickerField(
                    value = lightModel,
                    onValueChange = { lightModel = it },
                    options = lightOptions,
                    label = "Fast model (auto-detected)",
                    isLoading = verdict == HelixBridge.KeyCheckState.Checking,
                    onRefresh = if (hasKey) ({ bridge.refreshModels(kind, force = true) }) else null,
                    supportingText = if (lightNotInList) "Not in $displayName's list" else null,
                )
                Text(
                    text = "Used for questions Helix detects automatically — answers stream in fast.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
                if (settings.activeProvider == kind) {
                    Text(
                        text = if (hasKey) {
                            "Active provider for answers."
                        } else {
                            "Selected, but with no key stored Helix answers with the built-in deterministic provider."
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = if (hasKey) tokens.success else tokens.danger,
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
                        Text("Remove stored key", color = tokens.danger)
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

@Composable
private fun KeyCheckStatusRow(verdict: HelixBridge.KeyCheckState, hasKey: Boolean) {
    val tokens = HelixTheme.tokens
    when (verdict) {
        HelixBridge.KeyCheckState.Idle -> if (hasKey) {
            Text("Key set", style = MaterialTheme.typography.bodySmall, color = tokens.inkSecondary)
        }

        HelixBridge.KeyCheckState.Checking -> Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
            Text("Checking key…", style = MaterialTheme.typography.bodySmall, color = tokens.inkSecondary)
        }

        is HelixBridge.KeyCheckState.Valid -> Text(
            text = "Key OK · ${verdict.chatModelCount} chat models · ${relativeLabel(verdict.checkedAtMillis)}",
            style = MaterialTheme.typography.bodySmall,
            color = tokens.success,
        )

        is HelixBridge.KeyCheckState.Unsupported -> Text(
            text = verdict.message,
            style = MaterialTheme.typography.bodySmall,
            color = onTintColor(tokens.warning),
        )

        is HelixBridge.KeyCheckState.Failed -> Text(
            text = "Couldn't verify: ${verdict.message}. You can still save the key.",
            style = MaterialTheme.typography.bodySmall,
            color = HelixTheme.tokens.warning,
        )

        is HelixBridge.KeyCheckState.Invalid -> Text(
            text = verdict.message,
            style = MaterialTheme.typography.bodySmall,
            color = tokens.danger,
        )
    }
}

private fun saveProvider(
    bridge: HelixBridge,
    kind: String,
    apiKey: String,
    smartModel: String,
    lightModel: String,
) {
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
    // Saved last: setApiKey triggers validation, which reads the model the
    // settings update above is persisting.
    if (apiKey.isNotBlank()) bridge.setApiKey(kind, apiKey)
}

@Composable
private fun OmiKeyDialog(
    bridge: HelixBridge,
    hasKey: Boolean,
    onDismiss: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    var apiKey by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.extraLarge,
        containerColor = HelixTheme.tokens.surface,
        titleContentColor = HelixTheme.tokens.ink,
        textContentColor = HelixTheme.tokens.ink,
        title = { Text("Omi connection", style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    label = { Text(if (hasKey) "Replace stored key" else "Developer API key") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "Create a Developer API key (omi_dev_…) in the Omi app under " +
                        "Settings → Developer. MCP keys (omi_mcp_…) will not work.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
                if (hasKey) {
                    TextButton(
                        onClick = {
                            bridge.setApiKey(OmiImportService.KEY_KIND, null)
                            onDismiss()
                        },
                    ) {
                        Text("Remove stored key", color = tokens.danger)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    bridge.setApiKey(OmiImportService.KEY_KIND, apiKey)
                    onDismiss()
                },
                enabled = apiKey.isNotBlank(),
            ) {
                Text("Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun OmiRelayDialog(
    bridge: HelixBridge,
    hasUrl: Boolean,
    onDismiss: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    var feedUrl by remember { mutableStateOf("") }
    // http:// is allowed for self-hosted relays (e.g. wrangler dev on a LAN
    // box); the hosted Cloudflare relay is always https.
    val trimmedUrl = feedUrl.trim()
    val looksValid = (trimmedUrl.startsWith("https://") || trimmedUrl.startsWith("http://")) &&
        trimmedUrl.contains("/feed/")

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.extraLarge,
        containerColor = HelixTheme.tokens.surface,
        titleContentColor = HelixTheme.tokens.ink,
        textContentColor = HelixTheme.tokens.ink,
        title = { Text("Live transcript relay", style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = feedUrl,
                    onValueChange = { feedUrl = it },
                    label = { Text(if (hasUrl) "Replace relay feed URL" else "Relay feed URL") },
                    placeholder = { Text("https://….workers.dev/feed/<token>") },
                    singleLine = true,
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "Deploy relay/omi-relay (see its README), set the /hook/<token>/transcript " +
                        "URL as Omi's Real-Time Transcript Webhook, and paste the matching /feed/<token> " +
                        "URL here. The token is the only auth — keep it private.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
                if (hasUrl) {
                    TextButton(
                        onClick = {
                            bridge.stopOmiLive()
                            bridge.setApiKey(HelixBridge.OMI_RELAY_KEY_KIND, null)
                            onDismiss()
                        },
                    ) {
                        Text("Remove relay URL", color = tokens.danger)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    bridge.setApiKey(HelixBridge.OMI_RELAY_KEY_KIND, feedUrl)
                    onDismiss()
                },
                enabled = looksValid,
            ) {
                Text("Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

/** One row of the skill picker: check for the active skill, pencil for customs. */
@Composable
private fun SkillRow(
    skill: ActiveSkill,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onEdit: (() -> Unit)?,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect)
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Fixed-size slot keeps labels aligned whether or not a check shows.
        Box(modifier = Modifier.size(18.dp), contentAlignment = Alignment.Center) {
            if (isSelected) {
                Icon(
                    Icons.Outlined.CheckCircle,
                    contentDescription = "Active skill",
                    tint = tokens.success,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(
                text = skill.label,
                style = MaterialTheme.typography.titleSmall,
                color = tokens.ink,
            )
            Text(
                text = if (skill.isBuiltIn) "Built-in" else "Custom",
                style = MaterialTheme.typography.labelSmall,
                color = tokens.inkSecondary,
            )
        }
        if (onEdit != null) {
            IconButton(onClick = onEdit) {
                Icon(
                    Icons.Outlined.Edit,
                    contentDescription = "Edit ${skill.label}",
                    tint = tokens.accentDeep,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

/**
 * Name + prompt editor for a custom skill (iOS CustomSkillSheet). Saving
 * upserts the skill and activates it immediately; editing an existing custom
 * also offers deletion.
 */
@Composable
private fun CustomSkillDialog(
    existing: ActiveSkill?,
    onDismiss: () -> Unit,
    onSave: (label: String, prompt: String) -> Unit,
    onDelete: (() -> Unit)?,
) {
    val tokens = HelixTheme.tokens
    var name by remember { mutableStateOf(existing?.label.orEmpty()) }
    var prompt by remember { mutableStateOf(existing?.prompt.orEmpty()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.extraLarge,
        containerColor = HelixTheme.tokens.surface,
        titleContentColor = HelixTheme.tokens.ink,
        textContentColor = HelixTheme.tokens.ink,
        title = {
            Text(
                if (existing == null) "Custom skill" else "Edit custom skill",
                style = MaterialTheme.typography.headlineSmall,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Name") },
                    placeholder = { Text("e.g. Sales Coaching") },
                    singleLine = true,
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = prompt,
                    onValueChange = { prompt = it },
                    label = { Text("System prompt") },
                    placeholder = { Text("How should Helix answer while this skill is active?") },
                    maxLines = 6,
                    shape = MaterialTheme.shapes.medium,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "The skill is added to the picker and activated immediately.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
                if (onDelete != null) {
                    TextButton(onClick = onDelete) {
                        Text("Delete skill", color = tokens.danger)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onSave(name.trim(), prompt.trim()) },
                enabled = name.isNotBlank() && prompt.isNotBlank(),
            ) {
                Text("Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

/** Conversate glasses-interface settings (spec §5.5). */
@Composable
fun ConversateSettingsSection(bridge: HelixBridge) {
    val prefs by bridge.conversatePrefs.collectAsStateWithLifecycle()
    HelixSection(title = "Conversate", subtitle = "What appears on the glasses during a session") {
        ToggleRow("Live captions", prefs.captionsOn) { bridge.setConversatePrefs(prefs.copy(captionsOn = it)) }
        ToggleRow("AI cues", prefs.cuesOn) { bridge.setConversatePrefs(prefs.copy(cuesOn = it)) }
        ToggleRow("Auto pop-up", prefs.autoPopup, detail = "Off: new cues wait until you tap.") {
            bridge.setConversatePrefs(prefs.copy(autoPopup = it))
        }
        SliderRow("Cue duration", (prefs.cueDurationMillis / 1000).toInt(), 3..15, suffix = " s") {
            bridge.setConversatePrefs(prefs.copy(cueDurationMillis = it * 1_000L))
        }
    }
}
