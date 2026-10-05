// Wires the Conversate pieces together and is the only Conversate type
// HelixBridge talks to. Call every method from the bridge scope (main thread);
// the session is not thread-safe by design.
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
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
            if (session.isLive) end()
            scope.launch { driver.shutdown() }
        }
    }

    fun setPrefs(prefs: ConversatePrefs) { session.updatePrefs(prefs); render() }

    fun setPrepNotes(notes: List<PrepNote>) {
        prepNotes = notes
        session.setPrepNotes(notes.map { it.toRef() })
    }

    fun handleTouchpad(frame: G1TouchpadFrame): Boolean {
        if (TouchpadOwner.route(frame.notifyIndex, enabledState.value) != TouchpadOwner.CONVERSATE) return false
        G1InputMapper.map(frame, session.selectContext)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
        return true
    }

    fun handleStatus(event: G1StatusEvent?) {
        if (!enabledState.value) return
        G1InputMapper.map(event)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
    }

    fun intent(intent: ConversateIntent, source: IntentSource = IntentSource.PHONE) {
        if (!deduper.accept(intent, source)) return
        apply(session.onIntent(intent))
    }

    fun onSegment(segment: TranscriptSegment) {
        if (!session.isLive) return
        captions.onSegment(segment)
        session.onCaptionLines(captions.lines())
        if (segment.isFinal) engine.onFinal(segment.text)
        render()
    }

    fun offerExternal(text: String, priority: HudArbiter.Priority) {
        if (!session.isLive) return
        val type = if (priority == HudArbiter.Priority.ANSWER) CueType.ANSWER else CueType.NOTICE
        val lines = text.trim()
        val title = if (type == CueType.ANSWER) "Answer" else "Notice"
        session.onCue(
            Cue(
                id = engine.nextCueId(),
                type = type,
                title = title,
                body = lines.take(CueParser.BODY_MAX),
                detail = lines.takeIf { it.length > CueParser.BODY_MAX }?.take(CueParser.DETAIL_MAX),
                createdAtMillis = clock(),
            ),
        )
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
