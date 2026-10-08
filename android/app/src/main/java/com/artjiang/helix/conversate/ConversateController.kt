// Wires the Conversate pieces together and is the only Conversate type
// HelixBridge talks to. Call every method from the bridge scope (main thread);
// the session is not thread-safe by design.
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.ring.R1Gesture
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class TouchpadOwner {
    CONVERSATE, LEGACY;

    companion object {
        /** Spec §4.1: while enabled, Conversate sees every index before TouchpadDecider. */
        fun route(@Suppress("UNUSED_PARAMETER") notifyIndex: Int, conversateEnabled: Boolean) =
            if (conversateEnabled) CONVERSATE else LEGACY
    }
}

class ConversateController(
    private val scope: CoroutineScope,
    sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    clearScreen: suspend () -> Unit,
    arbiter: HudArbiter,
    classify: suspend (String, Int) -> String,
    private val clock: () -> Long = System::currentTimeMillis,
    menu: MenuSpec = MenuSpec.load(),
    prompt: CuePrompt = CuePrompt.load(),
    private val onEffect: (SessionEffect) -> Unit,
) {
    private val composer = G1HudComposer()
    private val captions = CaptionBuffer()
    private val session = ConversateSession(
        menu = menu,
        clock = clock,
        detailPageCount = composer::detailPageCount,
        textPageCount = composer::textPageCount,
    )
    private val driver = ConversateHudDriver(scope, sendScreen, clearScreen, arbiter, clock)
    private val deduper = IntentDeduper(clock)
    private val engine = CueEngine(scope, classify, prompt, clock, emit = { cue -> session.onCue(cue); render() })
    private var prepNotes: List<PrepNote> = emptyList()
    private var ticker: Job? = null

    private val enabledState = MutableStateFlow(false)
    val enabled: StateFlow<Boolean> = enabledState.asStateFlow()
    private val liveState = MutableStateFlow(false)
    val isLive: StateFlow<Boolean> = liveState.asStateFlow()
    private val pausedState = MutableStateFlow(false)

    /** One pause state for the glasses menu and the phone button. */
    val paused: StateFlow<Boolean> = pausedState.asStateFlow()
    private val screenState = MutableStateFlow<ScreenModel>(ScreenModel.Blank)
    val screen: StateFlow<ScreenModel> = screenState.asStateFlow()
    private val previewState = MutableStateFlow("")
    val hudPreview: StateFlow<String> = previewState.asStateFlow()
    val cueFailures: StateFlow<Int> = engine.failures

    fun setEnabled(enabled: Boolean) {
        if (enabledState.value == enabled) return
        enabledState.value = enabled
        if (!enabled) {
            // Release a mic opened for a glasses Ask before going hands-off.
            if (session.isAskListening) apply(session.cancelAsk())
            if (session.isLive) end()
            scope.launch { driver.shutdown() }
        }
    }

    fun setPrefs(prefs: ConversatePrefs) {
        session.updatePrefs(prefs)
        // Disabled means hands off the lens entirely (no stray 0x18).
        if (enabledState.value) render()
    }

    fun setPrepNotes(notes: List<PrepNote>) {
        prepNotes = notes
        session.setPrepNotes(notes.map { it.toRef() })
    }

    fun handleTouchpad(frame: G1TouchpadFrame): Boolean {
        if (TouchpadOwner.route(frame.notifyIndex, enabledState.value) != TouchpadOwner.CONVERSATE) return false
        G1InputMapper.map(frame, session.selectContext)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
        return true
    }

    /** R1 ring gesture (Plan B). Same intents as the touchpad; duplicates are deduped. */
    fun handleRing(gesture: R1Gesture) {
        if (!enabledState.value) return
        R1InputMapper.map(gesture)?.let { intent(it, IntentSource.R1) }
    }

    fun handleStatus(event: G1StatusEvent?) {
        if (!enabledState.value) return
        G1InputMapper.map(event)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
    }

    fun intent(intent: ConversateIntent, source: IntentSource = IntentSource.PHONE) {
        if (!deduper.accept(intent, source)) return
        apply(session.onIntent(intent))
    }

    /**
     * Partials and finals from the active transcript source. Returns true when
     * the segment was consumed as the wearer's Ask question (contract 0.3 §6),
     * so the legacy question pipeline must not also act on it.
     */
    fun onSegment(segment: TranscriptSegment): Boolean {
        if (enabledState.value && session.isAskListening && segment.isFinal && segment.text.isNotBlank()) {
            apply(session.onAskText(segment.text))
            return true
        }
        if (!session.isLive) return false
        captions.onSegment(segment)
        session.onCaptionLines(captions.lines())
        if (segment.isFinal) engine.onFinal(segment.text)
        render()
        return false
    }

    fun offerExternal(text: String, priority: HudArbiter.Priority) {
        if (!session.isLive) return
        val type = if (priority == HudArbiter.Priority.ANSWER) CueType.ANSWER else CueType.NOTICE
        session.onCue(externalCue(text, type))
        render()
    }

    /** An answer outside a live session (Display-only / idle): an AnswerCard on the lens. */
    fun showAnswer(text: String) = showCard(CueType.ANSWER, text)

    /**
     * Ask results (contract 0.3 §6): a live session gets a cue through the
     * normal cue path; otherwise the card opens as a detail overlay.
     */
    fun showCard(type: CueType, text: String) {
        if (!enabledState.value || text.isBlank()) return
        if (session.isLive) {
            offerExternal(text, if (type == CueType.ANSWER) HudArbiter.Priority.ANSWER else HudArbiter.Priority.NOTIFICATION)
            return
        }
        val effects = session.showAnswer(externalCue(text, type))
        if (effects.isEmpty()) render() else apply(effects)
    }

    private fun externalCue(text: String, type: CueType): Cue {
        // Collapse newlines: HudPaginator wraps on spaces only, so an embedded
        // newline would add rows beyond the 5-line card.
        val lines = text.trim().replace(Regex("\\s+"), " ")
        return Cue(
            id = engine.nextCueId(),
            type = type,
            title = if (type == CueType.ANSWER) "Answer" else "Notice",
            body = lines.take(CueParser.BODY_MAX),
            detail = lines.takeIf { it.length > CueParser.BODY_MAX }?.take(CueParser.DETAIL_MAX),
            createdAtMillis = clock(),
        )
    }

    val currentPrefs: ConversatePrefs get() = session.currentPrefs

    val isAskListening: Boolean get() = session.isAskListening

    /** Phone-side mode change; the glasses picker opens on it next time. */
    fun setMode(mode: HelixMode) {
        session.setMode(mode)
        if (enabledState.value) render()
    }

    /** Dashboard rows for [kind] (contract 0.3 §5), e.g. after a RequestPanel. */
    fun setPanelRows(kind: String, rows: List<PanelRow>) {
        session.setPanelRows(kind, rows)
        if (enabledState.value) render()
    }

    fun panelRows(kind: String): List<PanelRow> = session.panelRows(kind)

    /** Re-sends the current screen, e.g. after the glasses reconnect. */
    fun redraw() {
        if (!enabledState.value) return
        driver.invalidate()
        render()
    }

    fun start(prepNoteId: String?) = apply(session.startLive(prepNoteId))

    fun end() = apply(session.endLive())

    /** Phone-side pause; emits the same effect as the glasses menu toggle. */
    fun setPaused(paused: Boolean) {
        if (!session.isLive || pausedState.value == paused) return
        session.setPaused(paused)
        apply(listOf(SessionEffect.SetPaused(paused)))
    }

    private fun apply(effects: List<SessionEffect>) {
        effects.forEach { effect ->
            when (effect) {
                is SessionEffect.Start -> {
                    captions.clear()
                    engine.reset()
                    engine.setPrepNote(prepNotes.firstOrNull { it.id == effect.prepNoteId }?.text)
                    liveState.value = true
                    pausedState.value = false
                    startTicker()
                }
                SessionEffect.End -> {
                    liveState.value = false
                    pausedState.value = false
                    engine.reset()
                    captions.clear()
                }
                is SessionEffect.SetPaused -> pausedState.value = effect.paused
                else -> Unit
            }
            onEffect(effect)
        }
        render()
    }

    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                delay(250)
                session.tick()
                render()
                if (!session.isLive && screenState.value == ScreenModel.Blank) break
            }
        }
    }

    private fun render() {
        val model = session.screen()
        screenState.value = model
        val frame = composer.compose(model)
        previewState.value = frame?.text.orEmpty()
        driver.submit(frame, interactive = model.isInteractive)
    }
}
