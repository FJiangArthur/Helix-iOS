// Assistant tab, conversation-first: a 48 dp header, then either the expanded
// hero (true empty state) inside the feed list or a pinned compact listening
// bar above it, with errors and the keyless banner pinned, and the ask bar
// above the keyboard. Listening setup lives in a bottom sheet.
package com.artjiang.helix.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.outlined.RestartAlt
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.BuildConfig
import com.artjiang.helix.AutomaticNoteReceipt
import com.artjiang.helix.FeedEntry
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.R
import com.artjiang.helix.ai.ModelRole
import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.ble.LensConnectionState
import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.TranscriptionSource

/** Everything the hero/compact listening surfaces render. */
private data class ListeningState(
    val statusText: String,
    val statusTint: Color,
    val statusPulsing: Boolean,
    val setupSummary: String,
    val canAsk: Boolean,
    val askNowHint: String,
    val isListening: Boolean,
    val isAnswering: Boolean,
    val partial: String,
    val showTestAudioPill: Boolean,
)

/** Everything the hero/compact listening surfaces can trigger. */
private class ListeningActions(
    val onOpenSetup: () -> Unit,
    val onAskNow: () -> Unit,
    val onMicTap: () -> Unit,
    val onMicLongPress: () -> Unit,
)

@Composable
fun AssistantScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    val settings by bridge.settings.collectAsStateWithLifecycle()
    val isListening by bridge.isListening.collectAsStateWithLifecycle()
    val isAnswering by bridge.isAnswering.collectAsStateWithLifecycle()
    val partial by bridge.partialTranscript.collectAsStateWithLifecycle()
    val transcript by bridge.transcriptText.collectAsStateWithLifecycle()
    val speechError by bridge.speechError.collectAsStateWithLifecycle()
    val effectiveProvider by bridge.effectiveProvider.collectAsStateWithLifecycle()
    val hudDelivery by bridge.hudDelivery.collectAsStateWithLifecycle()
    val activeSource by bridge.activeSource.collectAsStateWithLifecycle()
    val selectedSource by bridge.transcriptionSource.collectAsStateWithLifecycle()
    val questionMode by bridge.questionMode.collectAsStateWithLifecycle()
    val questionSensitivity by bridge.questionSensitivity.collectAsStateWithLifecycle()
    val providerError by bridge.providerError.collectAsStateWithLifecycle()
    val automaticNoteReceipt by bridge.automaticNoteReceipt.collectAsStateWithLifecycle()
    val leftLens by bridge.leftLens.collectAsStateWithLifecycle()
    val rightLens by bridge.rightLens.collectAsStateWithLifecycle()
    val feed by bridge.feed.collectAsStateWithLifecycle()
    val testAudioActive by bridge.debugInjectionActive.collectAsStateWithLifecycle()
    // The in-flight answer's tokens. Non-blank only while one is streaming; it
    // empties in the same frame the finished ANSWER entry joins the feed.
    val streamingAnswer by bridge.answerStreamingText.collectAsStateWithLifecycle()
    // True once answering has started but no token has arrived yet — a
    // reasoning model emits nothing while it thinks, so this is the honest
    // signal the wearer sees instead of a bare spinner before a text burst.
    val isThinking by bridge.isThinking.collectAsStateWithLifecycle()

    // Survives tab switches and fold/unfold via SaveableStateProvider in HelixApp.
    var draft by rememberSaveable { mutableStateOf("") }
    var showSetupSheet by remember { mutableStateOf(false) }
    var confirmNewConversation by remember { mutableStateOf(false) }

    val micPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> if (granted) bridge.startListening() }

    /**
     * Whether RECORD_AUDIO is already held.
     *
     * Read at tap time, not remembered: the user can revoke the permission in
     * system settings while the app is alive, and a cached value would then send
     * us down the "already granted" branch forever.
     */
    val appContext = LocalContext.current.applicationContext
    val micGranted: () -> Boolean = {
        ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    val glassesConnected = leftLens == LensConnectionState.READY || rightLens == LensConnectionState.READY
    val canAsk = !isAnswering && (transcript.isNotBlank() || partial.isNotBlank())
    val keyless = effectiveProvider == ProviderKind.DETERMINISTIC
    // Latched: TranscriptCompleted clears the partial one frame before the
    // final lands in the feed, which would flap the hero back for a frame.
    var everHadConversation by rememberSaveable { mutableStateOf(false) }
    val hasConversation = feed.isNotEmpty() || partial.isNotBlank() || isAnswering || everHadConversation
    LaunchedEffect(hasConversation) { if (hasConversation) everHadConversation = true }

    val listening = ListeningState(
        statusText = when {
            isAnswering -> "Answering"
            isListening -> "Listening · ${sourceTitle(activeSource ?: selectedSource)}"
            else -> "Idle"
        },
        statusTint = when {
            isAnswering -> tokens.gold
            isListening -> tokens.success
            else -> tokens.inkMuted
        },
        statusPulsing = isListening || isAnswering,
        // Leads with the skill and conversation mode — what actually shapes the
        // answers — and drops the source, which is visible in the status pill
        // while listening. One line, ellipsized in the narrow bar.
        setupSummary = "${settings.resolvedSkill().label} · ${modeTitle(settings.mode)} · " +
            questionModeTitle(questionMode),
        canAsk = canAsk,
        askNowHint = if (questionMode == QuestionMode.ON_DEMAND) {
            "Answer the last minute of conversation"
        } else {
            "Ask about the latest transcript"
        },
        isListening = isListening,
        isAnswering = isAnswering,
        partial = partial,
        showTestAudioPill = testAudioActive,
    )
    val actions = remember(bridge, micPermissionLauncher) {
        ListeningActions(
            onOpenSetup = { showSetupSheet = true },
            onAskNow = bridge::triggerManualQuestion,
            // Omi needs no microphone: the pendant captures audio.
            onMicTap = {
                when {
                    bridge.isListening.value -> bridge.stopListening()
                    bridge.transcriptionSource.value == TranscriptionSource.OMI -> bridge.startListening()
                    // Ask for the mic ONLY when we do not already hold it.
                    //
                    // `RequestPermission.launch` on an ALREADY-GRANTED permission
                    // returns granted immediately without showing a dialog, and
                    // the callback then calls startListening(). So on a device
                    // where the mic was granted long ago, a second tap after
                    // stopping silently restarted the session — the wearer could
                    // stop, but it always came back. Check first, and only
                    // launch the request when the permission is genuinely
                    // missing.
                    micGranted() -> bridge.startListening()
                    else -> micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            // Debug builds only: long-press streams the bundled test WAV
            // through the real realtime pipeline (no-op in release).
            onMicLongPress = { bridge.startDebugAudioInjection() },
        )
    }

    val listState = rememberLazyListState()
    val bottomSlopPx = with(LocalDensity.current) { 32.dp.roundToPx() }
    // At-bottom with 32 dp slop: the last item's bottom edge is within slop of
    // the viewport end (an empty list counts as bottom).
    val atBottom by remember(listState, bottomSlopPx) {
        derivedStateOf {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull() ?: return@derivedStateOf true
            last.index == info.totalItemsCount - 1 &&
                last.offset + last.size <= info.viewportEndOffset + bottomSlopPx
        }
    }
    // Follow the feed until the reader scrolls up to reread; re-arm when they
    // return to the bottom. (A programmatic animateScrollToItem can briefly
    // break the flag mid-flight, but it always lands at the bottom and re-arms.)
    var followFeed by rememberSaveable { mutableStateOf(true) }
    LaunchedEffect(listState) {
        snapshotFlow { listState.isScrollInProgress to atBottom }
            .collect { (scrolling, bottom) ->
                if (bottom) followFeed = true else if (scrolling) followFeed = false
            }
    }
    // Snap for streaming growth (transcript partial AND answer tokens), animate
    // for whole new entries.
    var seenFeedSize by remember { mutableIntStateOf(feed.size) }
    LaunchedEffect(feed.size, partial.length, streamingAnswer.length) {
        val newEntry = feed.size != seenFeedSize
        seenFeedSize = feed.size
        if (!followFeed) return@LaunchedEffect
        val lastIndex = listState.layoutInfo.totalItemsCount - 1
        if (lastIndex < 0) return@LaunchedEffect
        if (newEntry) listState.animateScrollToItem(lastIndex) else listState.scrollToItem(lastIndex)
    }

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val widthClass = helixWidthClass(maxWidth)
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .helixMaxContentWidth(640.dp)
                .fillMaxHeight(),
        ) {
            AssistantHeader(
                glassesConnected = glassesConnected,
                widthClass = widthClass,
                canStartNew = feed.isNotEmpty() || isAnswering,
                onStartNew = { confirmNewConversation = true },
            )

            Box(modifier = Modifier.padding(horizontal = HelixSpacing.screen)) {
                ConversateCard(bridge)
            }

            AnimatedContent(
                targetState = hasConversation,
                transitionSpec = {
                    (
                        fadeIn(tween(HelixMotion.medMillis, easing = HelixMotion.easeOutQuint)) +
                            expandVertically(tween(HelixMotion.medMillis, easing = HelixMotion.easeOutQuint))
                        ).togetherWith(
                        fadeOut(tween(HelixMotion.fastMillis)) +
                            shrinkVertically(tween(HelixMotion.fastMillis)),
                    )
                },
                label = "listeningBar",
            ) { conversation ->
                if (conversation) {
                    CompactListeningBar(state = listening, actions = actions, widthClass = widthClass)
                } else {
                    Spacer(Modifier.fillMaxWidth())
                }
            }

            if (speechError.isNotBlank()) {
                DismissibleError(
                    text = speechError,
                    onDismiss = bridge::clearSpeechError,
                    modifier = Modifier.padding(
                        horizontal = HelixSpacing.screen,
                        vertical = HelixSpacing.s4,
                    ),
                )
            }
            if (providerError.isNotBlank()) {
                DismissibleError(
                    text = providerError,
                    onDismiss = bridge::clearProviderError,
                    modifier = Modifier.padding(
                        horizontal = HelixSpacing.screen,
                        vertical = HelixSpacing.s4,
                    ),
                )
            }
            automaticNoteReceipt?.let { receipt ->
                AutomaticNoteBanner(
                    receipt = receipt,
                    onUndo = { bridge.undoAutomaticNotes(receipt.items) },
                    onDismiss = bridge::dismissAutomaticNoteReceipt,
                )
            }
            if (keyless) {
                Text(
                    text = "No AI key — answers are placeholders. Add one in Settings.",
                    style = MaterialTheme.typography.labelMedium,
                    color = tokens.warning,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(
                        horizontal = HelixSpacing.screen,
                        vertical = HelixSpacing.s4,
                    ),
                )
            }

            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = HelixSpacing.screen),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    top = HelixSpacing.s4,
                    bottom = HelixSpacing.s16,
                ),
                verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            ) {
                if (!hasConversation) {
                    item(key = "hero") {
                        ExpandedHero(state = listening, actions = actions, widthClass = widthClass)
                    }
                }

                items(count = feed.size, key = { feed[it].id }) { index ->
                    val entry = feed[index]
                    val isLatestAnswer = entry.kind == FeedEntry.Kind.ANSWER &&
                        feed.subList(index + 1, feed.size).none { it.kind == FeedEntry.Kind.ANSWER }
                    FeedRow(
                        entry = entry,
                        hudLabel = hudDelivery.labelForAnswer(entry.id),
                        onSendToGlasses = if (isLatestAnswer) {
                            { bridge.presentToGlasses(entry.text, ownerFeedEntryId = entry.id) }
                        } else {
                            null
                        },
                        onSaveSession = if (isLatestAnswer) {
                            { bridge.saveSession(question = entry.question.orEmpty(), answer = entry.text) }
                        } else {
                            null
                        },
                        onThinkDeeper = entry.question
                            ?.takeIf { shouldOfferThinkDeeper(entry) }
                            ?.let { question -> { bridge.thinkDeeper(question) } },
                    )
                }

                if (isListening && partial.isNotBlank()) {
                    item(key = "partial") {
                        Text(
                            text = buildAnnotatedString {
                                withStyle(SpanStyle(color = tokens.inkMuted, fontStyle = FontStyle.Italic)) {
                                    append(partial)
                                }
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(horizontal = HelixSpacing.s8),
                        )
                    }
                }

                // The answer being generated right now. Styled like a finished
                // answer card so the text does not reflow when it lands, but
                // with no action buttons — there is nothing to send or save
                // until it is complete. Kept last so the auto-scroll target
                // (the final item) follows the growing answer.
                if (streamingAnswer.isNotBlank()) {
                    item(key = "streamingAnswer") {
                        StreamingAnswerRow(text = streamingAnswer)
                    }
                } else if (isThinking) {
                    // No tokens yet: shown for the reasoning-model gap between
                    // "answering started" and the first delta, so the wearer
                    // sees an honest "Thinking…" instead of a stalled spinner.
                    item(key = "thinkingRow") {
                        ThinkingRow()
                    }
                }
            }

            AskBar(
                draft = draft,
                onDraftChange = { draft = it },
                enabled = draft.isNotBlank() && !isAnswering,
                onSend = {
                    bridge.askQuestion(draft)
                    draft = ""
                },
            )
        }
    }

    if (confirmNewConversation) {
        AlertDialog(
            onDismissRequest = { confirmNewConversation = false },
            title = { Text("Start a new conversation?") },
            text = {
                Text(
                    "This clears the conversation on this screen. " +
                        "Sessions you have saved are not affected.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmNewConversation = false
                    bridge.startNewConversation()
                    // Drop the latch so the empty state can come back. Without
                    // this the feed empties but the hero never returns, so the
                    // clear looks like it did nothing at all.
                    everHadConversation = false
                }) { Text("Clear") }
            },
            dismissButton = {
                TextButton(onClick = { confirmNewConversation = false }) { Text("Cancel") }
            },
        )
    }

    if (showSetupSheet) {
        ListeningSetupSheet(
            bridge = bridge,
            settings = settings,
            selectedSource = selectedSource,
            questionMode = questionMode,
            questionSensitivity = questionSensitivity,
            conversationMode = settings.mode,
            onDismiss = { showSetupSheet = false },
        )
    }
}

/** Explicit receipt for final-only saves to Helix's internal Knowledge store. */
@Composable
private fun AutomaticNoteBanner(
    receipt: AutomaticNoteReceipt,
    onUndo: () -> Unit,
    onDismiss: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    LinenCard(
        modifier = Modifier.padding(horizontal = HelixSpacing.screen, vertical = HelixSpacing.s4),
        tint = CardTint.Support,
        contentPadding = HelixSpacing.s8,
    ) {
        Text(
            text = receipt.message,
            style = MaterialTheme.typography.labelMedium,
            color = tokens.ink,
        )
        Text(
            text = receipt.preview,
            style = MaterialTheme.typography.bodySmall,
            color = tokens.inkSecondary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s4)) {
            TextButton(onClick = onUndo) { Text("Undo") }
            TextButton(onClick = onDismiss) { Text("Dismiss") }
        }
    }
}

/** 48 dp screen header: Fraunces title plus the glasses status pill. */
@Composable
private fun AssistantHeader(
    glassesConnected: Boolean,
    widthClass: HelixWidthClass,
    canStartNew: Boolean,
    onStartNew: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .padding(horizontal = HelixSpacing.screen),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
    ) {
        Text(
            text = "Assistant",
            style = MaterialTheme.typography.headlineMedium,
            color = tokens.ink,
        )
        Spacer(Modifier.weight(1f))
        // Starting a fresh conversation lives HERE, on the main screen, not
        // buried in the setup sheet behind a chip that reads as a preferences
        // dropdown. The wearer reported there was "no start new session
        // button" — there wasn't one they could find.
        if (canStartNew) {
            IconButton(onClick = onStartNew) {
                Icon(
                    imageVector = Icons.Outlined.RestartAlt,
                    contentDescription = "Start a new conversation",
                    tint = tokens.accentDeep,
                )
            }
        }
        StatusPill(
            text = when {
                widthClass == HelixWidthClass.Narrow -> if (glassesConnected) "Glasses" else "Offline"
                glassesConnected -> "Glasses connected"
                else -> "Glasses offline"
            },
            tint = if (glassesConnected) tokens.success else tokens.inkMuted,
        )
    }
}

/**
 * True-empty-state hero: warm art, status pills, setup chip + Ask now, the big
 * mic, and the empty-state copy. Lives inside the feed list and is replaced by
 * [CompactListeningBar] once conversation exists.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
private fun ExpandedHero(
    state: ListeningState,
    actions: ListeningActions,
    widthClass: HelixWidthClass,
) {
    val tokens = HelixTheme.tokens
    val shape = MaterialTheme.shapes.extraLarge
    val narrow = widthClass == HelixWidthClass.Narrow

    val energy by animateFloatAsState(
        targetValue = heroEnergy(state.isListening, state.partial),
        animationSpec = tween(HelixMotion.slowMillis),
        label = "energy",
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 200.dp, max = 360.dp)
            .clip(shape)
            .background(heroBackdropBrush(), shape),
    ) {
        Image(
            painter = painterResource(R.drawable.helix_assistant_hero),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alpha = 0.9f,
            modifier = Modifier.matchParentSize(),
        )
        Box(modifier = Modifier.matchParentSize().background(heroFadeBrush()))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(HelixSpacing.s16),
            verticalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
        ) {
            val pills: @Composable () -> Unit = {
                StatusPill(
                    text = state.statusText,
                    tint = state.statusTint,
                    pulsing = state.statusPulsing,
                )
                if (state.showTestAudioPill) {
                    StatusPill(text = "Test audio", tint = tokens.warning, pulsing = true)
                }
            }
            if (narrow) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
                    verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
                ) { pills() }
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
                    verticalAlignment = Alignment.CenterVertically,
                ) { pills() }
            }

            val setupChip: @Composable () -> Unit = {
                SetupChip(summary = state.setupSummary, onClick = actions.onOpenSetup)
            }
            val askNowButton: @Composable () -> Unit = {
                FilledTonalButton(
                    onClick = actions.onAskNow,
                    enabled = state.canAsk,
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = tokens.supportTint,
                        contentColor = tokens.ink,
                    ),
                ) {
                    Icon(
                        Icons.Outlined.Bolt,
                        contentDescription = state.askNowHint,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(HelixSpacing.s4))
                    Text("Ask now", maxLines = 1, softWrap = false)
                }
            }
            if (narrow) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
                    verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
                ) {
                    setupChip()
                    askNowButton()
                }
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // The chip yields width to the button: it shrinks (label
                    // ellipsizes) instead of squeezing "Ask now" into a
                    // one-character-per-line column.
                    Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                        setupChip()
                    }
                    askNowButton()
                }
            }

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
            ) {
                DebugInjectableMic(
                    isListening = state.isListening,
                    isAnswering = state.isAnswering,
                    onMicTap = actions.onMicTap,
                    onMicLongPress = actions.onMicLongPress,
                    size = 72.dp,
                )
                if (state.isListening) {
                    AnimatedWaveform(
                        active = true,
                        energy = energy,
                        color = tokens.accentDeep,
                        modifier = Modifier.fillMaxWidth(0.7f),
                    )
                }
                Text(
                    text = "Nothing heard yet — tap the mic to start listening, or ask below.",
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

/**
 * Pinned listening strip shown once conversation exists: status pill, setup
 * chip (folded into the pill on Narrow), Ask now, and a 40 dp mic. A slim
 * waveform runs underneath while listening.
 */
@Composable
private fun CompactListeningBar(
    state: ListeningState,
    actions: ListeningActions,
    widthClass: HelixWidthClass,
) {
    val tokens = HelixTheme.tokens
    val narrow = widthClass == HelixWidthClass.Narrow

    val energy by animateFloatAsState(
        targetValue = heroEnergy(state.isListening, state.partial),
        animationSpec = tween(HelixMotion.slowMillis),
        label = "energy",
    )

    Surface(
        color = tokens.bgRaised,
        contentColor = tokens.ink,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp)
                    .padding(horizontal = HelixSpacing.screen),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            ) {
                // The setup chip is the only entry to skill/mode selection, so
                // it ships on every width. On Narrow the status pill yields to
                // it (the pill's text also lives in the hero) rather than the
                // chip being dropped, which is what hid skills and modes.
                if (!narrow) {
                    StatusPill(
                        text = state.statusText,
                        tint = state.statusTint,
                        pulsing = state.statusPulsing,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                }
                if (state.showTestAudioPill) {
                    StatusPill(text = "Test audio", tint = tokens.warning, pulsing = true)
                }
                // Shares leftover width with the status pill so neither
                // squeezes the buttons; the label ellipsizes when tight.
                Box(Modifier.weight(1f, fill = false)) {
                    SetupChip(summary = state.setupSummary, onClick = actions.onOpenSetup)
                }
                if (widthClass == HelixWidthClass.Wide) {
                    FilledTonalButton(
                        onClick = actions.onAskNow,
                        enabled = state.canAsk,
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = tokens.supportTint,
                            contentColor = tokens.ink,
                        ),
                    ) {
                        Icon(
                            Icons.Outlined.Bolt,
                            contentDescription = state.askNowHint,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(HelixSpacing.s4))
                        Text("Ask now", maxLines = 1, softWrap = false)
                    }
                } else {
                    FilledTonalIconButton(
                        onClick = actions.onAskNow,
                        enabled = state.canAsk,
                        colors = IconButtonDefaults.filledTonalIconButtonColors(
                            containerColor = tokens.supportTint,
                            contentColor = tokens.ink,
                        ),
                    ) {
                        Icon(Icons.Outlined.Bolt, contentDescription = state.askNowHint)
                    }
                }
                DebugInjectableMic(
                    isListening = state.isListening,
                    isAnswering = state.isAnswering,
                    onMicTap = actions.onMicTap,
                    onMicLongPress = actions.onMicLongPress,
                    size = 40.dp,
                )
            }
            if (state.isListening) {
                AnimatedWaveform(
                    active = true,
                    energy = energy,
                    color = tokens.accentDeep,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(16.dp)
                        .padding(horizontal = HelixSpacing.screen),
                )
            }
            HairlineDivider()
        }
    }
}

/**
 * WarmMicButton owns its own click Surface (ui/Visuals.kt, not editable
 * here), so the debug long-press lives on an invisible overlay that captures
 * both gestures. The overlay exists only in debug builds — release keeps the
 * stock press behavior. The wrapper keeps the touch target at 48 dp even for
 * the 40 dp compact mic.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DebugInjectableMic(
    isListening: Boolean,
    isAnswering: Boolean,
    onMicTap: () -> Unit,
    onMicLongPress: () -> Unit,
    size: androidx.compose.ui.unit.Dp,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp),
    ) {
        WarmMicButton(
            isListening = isListening,
            isAnswering = isAnswering,
            onClick = onMicTap,
            size = size,
        )
        if (BuildConfig.DEBUG) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .combinedClickable(
                        interactionSource = null,
                        indication = null,
                        onClick = onMicTap,
                        onLongClickLabel = "Inject test audio",
                        onLongClick = onMicLongPress,
                    ),
            )
        }
    }
}

/**
 * Waveform amplitude stand-in: no live RMS yet, so the partial transcript's
 * churn drives the bars while listening.
 */
private fun heroEnergy(isListening: Boolean, partial: String): Float =
    if (isListening) ((partial.length % 40) / 40f).coerceAtLeast(0.15f) else 0f

/**
 * The answer currently being generated, rendered live below the feed.
 *
 * Deliberately NOT a [FeedEntry]: the feed is append-only and immutable, so a
 * growing answer would break both its item keys and the "exactly one entry per
 * answer" invariant. This row is transient — it vanishes when the completed
 * ANSWER entry appends. It mirrors the answer card's typography so the finished
 * text lands in place instead of jumping.
 */
@Composable
private fun StreamingAnswerRow(text: String) {
    val tokens = HelixTheme.tokens
    ChatBubble(
        author = "Helix",
        detail = "Answering",
        isUser = false,
        containerColor = tokens.surface,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.ink,
        )
    }
}

/**
 * Shown in place of [StreamingAnswerRow] before the first token arrives.
 * Deliberate asks route to the smart/reasoning model, which can pause before
 * emitting anything — without this row that gap reads as a stalled spinner
 * rather than a model that is working.
 */
@Composable
private fun ThinkingRow() {
    val tokens = HelixTheme.tokens
    ChatBubble(
        author = "Helix",
        detail = "Smart model",
        isUser = false,
        containerColor = tokens.surface,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            modifier = Modifier.semantics { contentDescription = "Thinking" },
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = tokens.gold,
            )
            Text(
                text = "Thinking…",
                style = MaterialTheme.typography.bodyMedium,
                color = tokens.inkSecondary,
            )
        }
    }
}

/** Bounded semantic chat bubble; alignment follows the message author. */
@Composable
private fun ChatBubble(
    author: String,
    detail: String? = null,
    isUser: Boolean,
    containerColor: Color,
    content: @Composable ColumnScope.() -> Unit,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Surface(
            color = containerColor,
            contentColor = tokens.ink,
            shape = MaterialTheme.shapes.large,
            tonalElevation = if (isUser) 0.dp else 1.dp,
            modifier = Modifier
                .widthIn(max = 520.dp)
                .semantics { contentDescription = "$author message" },
        ) {
            Column(
                modifier = Modifier.padding(horizontal = HelixSpacing.s12, vertical = HelixSpacing.s8),
                verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
                content = {
                    Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s4)) {
                        Text(
                            text = author,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isUser) tokens.accentDeep else tokens.inkSecondary,
                        )
                        detail?.let {
                            Text(
                                text = it,
                                style = MaterialTheme.typography.labelSmall,
                                color = tokens.inkMuted,
                            )
                        }
                    }
                    content()
                },
            )
        }
    }
}

/** Pure speaker policy shared by transcript and question bubbles (and JVM tests). */
internal data class SpeakerBubblePresentation(
    val author: String,
    val isWearer: Boolean,
)

internal fun speakerBubblePresentation(entry: FeedEntry): SpeakerBubblePresentation {
    val isWearer = entry.isUser
    val sourceName = entry.speaker?.trim()?.takeIf { it.isNotEmpty() }
    return SpeakerBubblePresentation(
        author = if (isWearer) "You" else sourceName ?: "Unknown speaker",
        isWearer = isWearer,
    )
}

/** One row of the conversation feed, styled as a real speaker-aware chat. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FeedRow(
    entry: FeedEntry,
    hudLabel: String?,
    onSendToGlasses: (() -> Unit)?,
    onSaveSession: (() -> Unit)? = null,
    onThinkDeeper: (() -> Unit)? = null,
) {
    val tokens = HelixTheme.tokens
    when (entry.kind) {
        FeedEntry.Kind.TRANSCRIPT -> {
            val speaker = speakerBubblePresentation(entry)
            ChatBubble(
                author = speaker.author,
                isUser = speaker.isWearer,
                containerColor = if (speaker.isWearer) tokens.accentTint else tokens.surface,
            ) {
                val paragraphs = remember(entry.text) { paragraphsForTranscript(entry.text) }
                Column(verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
                    paragraphs.forEach { paragraph ->
                        Text(
                            text = paragraph,
                            style = MaterialTheme.typography.bodyMedium,
                            color = tokens.inkSecondary,
                            textAlign = if (speaker.isWearer) TextAlign.End else TextAlign.Start,
                        )
                    }
                }
            }
        }

        FeedEntry.Kind.QUESTION -> {
            val speaker = speakerBubblePresentation(entry)
            ChatBubble(
                author = speaker.author,
                detail = "Question",
                isUser = speaker.isWearer,
                containerColor = if (speaker.isWearer) tokens.accentTint else tokens.supportTint,
            ) {
                Text(
                    text = entry.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = tokens.ink,
                    textAlign = if (speaker.isWearer) TextAlign.End else TextAlign.Start,
                )
            }
        }

        FeedEntry.Kind.ANSWER -> ChatBubble(
            author = "Helix",
            detail = entry.model?.let { "Model · $it" },
            isUser = false,
            containerColor = tokens.surface,
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
                hudLabel?.let { StatusPill(text = it, tint = tokens.gold) }
            }
            val paragraphs = remember(entry.text) {
                entry.text.split(Regex("\\n\\s*\\n")).map { it.trim() }.filter { it.isNotEmpty() }
            }
            Column(verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
                paragraphs.forEach { paragraph ->
                    Text(
                        text = paragraph,
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.ink,
                    )
                }
            }
            if (onSendToGlasses != null || onSaveSession != null || onThinkDeeper != null) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s4)) {
                    if (onThinkDeeper != null) {
                        TextButton(
                            onClick = onThinkDeeper,
                            colors = ButtonDefaults.textButtonColors(contentColor = tokens.accentDeep),
                        ) { Text("Think deeper · smart model") }
                    }
                    if (onSendToGlasses != null) {
                        TextButton(
                            onClick = onSendToGlasses,
                            colors = ButtonDefaults.textButtonColors(contentColor = tokens.accentDeep),
                        ) { Text("Send to glasses") }
                    }
                    if (onSaveSession != null) {
                        TextButton(
                            onClick = onSaveSession,
                            colors = ButtonDefaults.textButtonColors(contentColor = tokens.accentDeep),
                        ) { Text("Save session") }
                    }
                }
            }
        }

        FeedEntry.Kind.REMINDER -> ChatBubble(
            author = "Helix",
            detail = "Reminder",
            isUser = false,
            containerColor = tokens.goldTint,
        ) {
            Text(
                text = entry.text,
                style = MaterialTheme.typography.bodyLarge,
                color = tokens.ink,
            )
        }
    }
}

/**
 * Skill, source, question mode, and conversation mode — everything
 * set-and-forget, in one place so the wearer never has to leave the tab to
 * change how Helix answers. Content scrolls: the skill list grows with the
 * user's customs and the sheet has to survive the fold's cover screen.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListeningSetupSheet(
    bridge: HelixBridge,
    settings: HelixSettings,
    selectedSource: TranscriptionSource,
    questionMode: QuestionMode,
    questionSensitivity: QuestionSensitivity,
    conversationMode: ConversationMode,
    onDismiss: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val keyRevision by bridge.settingsRepository.keyRevision.collectAsStateWithLifecycle()
    val storedModel by bridge.openAiTranscriptionModel.collectAsStateWithLifecycle()
    val catalog by bridge.catalog.collectAsStateWithLifecycle()
    var modelDraft by remember(storedModel) { mutableStateOf(storedModel) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = tokens.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = HelixSpacing.screen)
                .padding(bottom = HelixSpacing.s32),
            verticalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
        ) {
            Text(
                text = "How Helix listens",
                style = MaterialTheme.typography.headlineSmall,
                color = tokens.ink,
            )

            // Skill first: it is what changes the answers most, and it used to
            // be reachable only from the Settings tab, split from the modes.
            val resolvedSkill = settings.resolvedSkill()
            Text(text = "Skill", style = MaterialTheme.typography.titleMedium, color = tokens.ink)
            SheetSkillPicker(
                skills = settings.selectableSkills(),
                selectedValue = resolvedSkill.value,
                onSelect = { value -> bridge.updateSettings { it.copy(activeSkillID = value) } },
            )
            Text(
                text = resolvedSkill.prompt,
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
            Text(
                text = "Create or edit custom skills under Settings → Assistant skill.",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkMuted,
            )

            HairlineDivider()

            Text(text = "Transcription source", style = MaterialTheme.typography.titleMedium, color = tokens.ink)
            Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
                TranscriptionSource.entries.forEach { source ->
                    FilterChip(
                        selected = selectedSource == source,
                        onClick = { bridge.setTranscriptionSource(source) },
                        label = { Text(sourceShortTitle(source), maxLines = 1) },
                        shape = HelixPillShape,
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = tokens.accentTint,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        ),
                    )
                }
            }
            Text(
                text = sourceSummary(selectedSource),
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )
            when (selectedSource) {
                TranscriptionSource.OPENAI_REALTIME -> {
                    val hasKey = remember(keyRevision) { bridge.hasApiKey(ProviderKind.OPENAI.name) }
                    if (!hasKey) {
                        Text(
                            text = "Needs an OpenAI key — add it under Settings → AI providers.",
                            style = MaterialTheme.typography.bodySmall,
                            color = tokens.warning,
                        )
                    }
                    // catalog is collected so a refresh recomposes the options.
                    ModelPickerField(
                        value = modelDraft,
                        onValueChange = {
                            modelDraft = it
                            bridge.setOpenAiTranscriptionModel(it)
                        },
                        options = remember(catalog, modelDraft) {
                            bridge.modelOptions(
                                ProviderKind.OPENAI.name,
                                ModelRole.TRANSCRIPTION,
                                pinned = modelDraft,
                            )
                        },
                        label = "Transcription model",
                        onRefresh = if (hasKey) {
                            { bridge.refreshModels(ProviderKind.OPENAI.name, force = true) }
                        } else {
                            null
                        },
                    )
                    Text(
                        text = "Streams the microphone to OpenAI while listening — billed per minute, silence included.",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkMuted,
                    )
                }

                TranscriptionSource.OMI -> {
                    val hasRelay = remember(keyRevision) { bridge.hasApiKey(HelixBridge.OMI_RELAY_KEY_KIND) }
                    if (!hasRelay) {
                        Text(
                            text = "Needs the relay URL — set it under Settings → Omi connection.",
                            style = MaterialTheme.typography.bodySmall,
                            color = tokens.warning,
                        )
                    }
                }

                TranscriptionSource.DEVICE -> Unit
            }

            HairlineDivider()

            Text(text = "Question mode", style = MaterialTheme.typography.titleMedium, color = tokens.ink)
            HelixSegmentedRow(
                entries = QuestionMode.entries,
                selected = questionMode,
                label = ::questionModeTitle,
            ) { mode -> bridge.setQuestionMode(mode) }
            Text(
                text = questionModeDetail(questionMode),
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )

            Text(text = "Question sensitivity", style = MaterialTheme.typography.titleMedium, color = tokens.ink)
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

            HairlineDivider()

            Text(text = "Conversation mode", style = MaterialTheme.typography.titleMedium, color = tokens.ink)
            HelixSegmentedRow(
                entries = ConversationMode.entries,
                selected = conversationMode,
                label = ::modeTitle,
            ) { mode -> bridge.setMode(mode) }
            Text(
                text = modeSummary(conversationMode),
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )

            HairlineDivider()

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = { bridge.startNewConversation(); onDismiss() })
                    .padding(vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "New conversation",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = tokens.ink,
                    )
                    Text(
                        text = "Clears the feed and lets repeat questions be answered again.",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                }
            }
        }
    }
}

/** Pill text field plus accent send button, pinned above the keyboard. */
@Composable
private fun AskBar(
    draft: String,
    onDraftChange: (String) -> Unit,
    enabled: Boolean,
    onSend: () -> Unit,
) {
    val tokens = HelixTheme.tokens
    Surface(
        color = tokens.bgRaised,
        contentColor = tokens.ink,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            HairlineDivider()
            Row(
                modifier = Modifier
                    .helixMaxContentWidth(640.dp)
                    .padding(horizontal = HelixSpacing.s12, vertical = HelixSpacing.s8)
                    // No-op while the scaffold already applies the IME inset;
                    // kept so the bar is still correct if that ever moves.
                    .imePadding(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = onDraftChange,
                    placeholder = { Text("Ask or paste a question", color = tokens.inkMuted) },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                    shape = HelixPillShape,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = tokens.surface,
                        unfocusedContainerColor = tokens.surface,
                        focusedBorderColor = tokens.accent,
                        unfocusedBorderColor = tokens.borderStrong,
                        cursorColor = tokens.accentDeep,
                    ),
                )
                FilledIconButton(
                    onClick = onSend,
                    enabled = enabled,
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = tokens.accent,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        disabledContainerColor = tokens.accentTint,
                        disabledContentColor = tokens.inkMuted,
                    ),
                ) {
                    Icon(Icons.Outlined.ArrowUpward, contentDescription = "Ask Helix")
                }
            }
        }
    }
}

/**
 * Selection-only skill picker for the setup sheet: one wrapping row of chips,
 * so 13 built-ins plus the user's customs stay compact on the fold's cover
 * screen and spread out on the inner one. Creating and editing customs stays
 * in Settings — this deliberately does not duplicate that editor.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SheetSkillPicker(
    skills: List<ActiveSkill>,
    selectedValue: String,
    onSelect: (String) -> Unit,
) {
    val tokens = HelixTheme.tokens
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.s4),
    ) {
        skills.forEach { skill ->
            FilterChip(
                selected = skill.value == selectedValue,
                onClick = { onSelect(skill.value) },
                label = { Text(skill.label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                shape = HelixPillShape,
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = tokens.accentTint,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
            )
        }
    }
}

/**
 * The one entry point to skill and mode selection. Reads as a control at a
 * glance: a leading tune glyph, the current skill/mode summary, and a trailing
 * chevron. The label ellipsizes rather than wrapping — it sits in a one-line
 * bar that also has to hold "Ask now" and the mic on the fold's cover screen.
 */
@Composable
private fun SetupChip(summary: String, onClick: () -> Unit) {
    val tokens = HelixTheme.tokens
    AssistChip(
        onClick = onClick,
        label = { Text(summary, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        leadingIcon = {
            Icon(
                Icons.Outlined.Tune,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        },
        trailingIcon = {
            Icon(
                Icons.Outlined.ExpandMore,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        },
        shape = HelixPillShape,
        border = AssistChipDefaults.assistChipBorder(enabled = true, borderColor = tokens.borderStrong),
        colors = AssistChipDefaults.assistChipColors(
            containerColor = tokens.surface.copy(alpha = 0.8f),
            labelColor = tokens.ink,
            leadingIconContentColor = tokens.accentDeep,
            trailingIconContentColor = tokens.inkSecondary,
        ),
        modifier = Modifier.semantics { contentDescription = "Assistant setup: $summary" },
    )
}
