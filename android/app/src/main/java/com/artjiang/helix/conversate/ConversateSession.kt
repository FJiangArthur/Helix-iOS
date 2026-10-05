// Conversate state machine (spec §4.2). Pure and single-threaded: the
// controller calls it from one coroutine context and asks for screen() after
// every input. Timers are driven by tick() against the injected clock.
package com.artjiang.helix.conversate

class ConversateSession(
    private val menu: MenuSpec,
    private val clock: () -> Long,
    prefs: ConversatePrefs = ConversatePrefs(),
    private val detailPageCount: (Cue) -> Int = { 1 },
    private val textPageCount: (String) -> Int = { 1 },
) {
    companion object {
        const val CONFIRM_END_MILLIS = 3_000L
        const val CONFIRM_GUARD_MILLIS = 400L
        const val LIVE_TITLE = "CONVERSATE"
        const val PICKER_TITLE = "PREP NOTE"
        const val SKIP_AND_START = "Skip & start"
        const val NO_PREP_NOTE = "No prep note for this session."
    }

    private enum class MenuKind { IDLE, LIVE, PICKER }

    private sealed interface Overlay {
        data class Menu(val kind: MenuKind, val cursor: Int) : Overlay
        data class Detail(val cue: Cue, val page: Int) : Overlay
        data class Prep(val page: Int) : Overlay
        data class Confirm(val until: Long) : Overlay
        data object Off : Overlay
    }

    private var prefs = prefs
    private var overlay: Overlay? = null
    private val queue = CueQueue()
    private var shown: Cue? = null
    private var shownUntil = 0L
    private var captions: List<String> = emptyList()
    private var prepNotes: List<PrepNoteRef> = emptyList()
    private var activePrep: PrepNoteRef? = null
    private var paused = false

    var isLive: Boolean = false
        private set

    /** True while a list is open: G1 long-press means SELECT, not MENU. */
    val selectContext: Boolean get() = overlay is Overlay.Menu

    fun setPrepNotes(notes: List<PrepNoteRef>) { prepNotes = notes }

    fun updatePrefs(prefs: ConversatePrefs) {
        this.prefs = prefs
        if (!prefs.cuesOn) { queue.clear(); shown = null }
    }

    fun setPaused(paused: Boolean) { this.paused = paused }

    fun startLive(prepNoteId: String?): List<SessionEffect> {
        isLive = true
        paused = false
        activePrep = prepNotes.firstOrNull { it.id == prepNoteId }
        queue.clear(); shown = null; captions = emptyList(); overlay = null
        return listOf(SessionEffect.Start(prepNoteId))
    }

    fun endLive(): List<SessionEffect> {
        isLive = false
        queue.clear(); shown = null; captions = emptyList(); overlay = null; activePrep = null
        return listOf(SessionEffect.End)
    }

    fun onCaptionLines(lines: List<String>) { captions = lines }

    fun onCue(cue: Cue) {
        if (!isLive || !prefs.cuesOn) return
        val now = clock()
        val current = currentShown(now)
        if (cue.type == CueType.ANSWER && current != null && current.type != CueType.ANSWER) {
            queue.offer(current, now)
            show(cue, now)
            return
        }
        queue.offer(cue, now)
        promote(now)
    }

    fun tick() {
        val now = clock()
        val o = overlay
        if (o is Overlay.Confirm && now > o.until) overlay = null
        if (shown != null && now >= shownUntil) shown = null
        promote(now)
    }

    /** Applies [intent]; afterwards a waiting cue may surface (e.g. once a menu closes). */
    fun onIntent(intent: ConversateIntent): List<SessionEffect> =
        handle(intent).also { promote(clock()) }

    private fun handle(intent: ConversateIntent): List<SessionEffect> {
        val now = clock()
        when (val o = overlay) {
            Overlay.Off -> { overlay = null; return emptyList() }
            is Overlay.Menu -> return onMenuIntent(o, intent)
            is Overlay.Detail -> {
                when (intent) {
                    ConversateIntent.NEXT -> overlay = o.copy(page = (o.page + 1).coerceAtMost(detailPageCount(o.cue) - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK -> { overlay = null; shown = null; promote(now) }
                    ConversateIntent.MENU -> overlay = Overlay.Menu(MenuKind.LIVE, 0)
                    else -> Unit
                }
                return emptyList()
            }
            is Overlay.Prep -> {
                val text = activePrep?.text ?: NO_PREP_NOTE
                when (intent) {
                    ConversateIntent.NEXT -> overlay = o.copy(page = (o.page + 1).coerceAtMost(textPageCount(text) - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK -> overlay = null
                    ConversateIntent.MENU -> overlay = Overlay.Menu(MenuKind.LIVE, 0)
                    else -> Unit
                }
                return emptyList()
            }
            is Overlay.Confirm -> {
                // Ignore a BACK that is really the same double-tap echoed.
                if (intent == ConversateIntent.BACK && now < o.until - CONFIRM_END_MILLIS + CONFIRM_GUARD_MILLIS) return emptyList()
                if (intent == ConversateIntent.BACK) return endLive()
                overlay = null
                return emptyList()
            }
            null -> Unit
        }
        if (intent == ConversateIntent.MENU) {
            overlay = Overlay.Menu(if (isLive) MenuKind.LIVE else MenuKind.IDLE, 0)
            return emptyList()
        }
        if (!isLive) return emptyList()
        val current = currentShown(now)
        when (intent) {
            ConversateIntent.NEXT, ConversateIntent.SELECT ->
                if (current != null) overlay = Overlay.Detail(current, 0)
                else queue.poll(now)?.let { show(it, now) }
            ConversateIntent.PREV -> if (current != null) { shown = null; promote(now) }
            ConversateIntent.BACK ->
                if (current != null) { shown = null; promote(now) }
                else overlay = Overlay.Confirm(now + CONFIRM_END_MILLIS)
            else -> Unit
        }
        return emptyList()
    }

    fun screen(): ScreenModel {
        val now = clock()
        return when (val o = overlay) {
            Overlay.Off -> ScreenModel.Blank
            is Overlay.Menu -> ScreenModel.Menu(menuTitle(o.kind), menuLabels(o.kind), o.cursor)
            is Overlay.Detail -> ScreenModel.CueDetail(o.cue, o.page)
            is Overlay.Prep -> ScreenModel.PrepNoteView(activePrep?.title ?: PICKER_TITLE, activePrep?.text ?: NO_PREP_NOTE, o.page)
            is Overlay.Confirm -> ScreenModel.ConfirmEnd
            null -> liveScreen(now)
        }
    }

    private fun liveScreen(now: Long): ScreenModel {
        if (!isLive) return ScreenModel.Blank
        val cue = currentShown(now)
        val pending = if (cue == null && !prefs.autoPopup) queue.count(now) else 0
        if (!paused && cue == null && pending == 0 && !prefs.captionsOn) return ScreenModel.Blank
        return ScreenModel.Live(cue, pending, captions, prefs.captionsOn, paused)
    }

    private fun onMenuIntent(o: Overlay.Menu, intent: ConversateIntent): List<SessionEffect> {
        val labels = menuLabels(o.kind)
        when (intent) {
            ConversateIntent.NEXT -> overlay = o.copy(cursor = (o.cursor + 1).coerceAtMost(labels.size - 1))
            ConversateIntent.PREV -> overlay = o.copy(cursor = (o.cursor - 1).coerceAtLeast(0))
            ConversateIntent.BACK, ConversateIntent.MENU ->
                overlay = if (o.kind == MenuKind.PICKER) Overlay.Menu(MenuKind.IDLE, 0) else null
            ConversateIntent.SELECT -> return activate(o)
            else -> Unit
        }
        return emptyList()
    }

    private fun activate(o: Overlay.Menu): List<SessionEffect> {
        if (o.kind == MenuKind.PICKER) {
            val note = if (o.cursor == 0) null else prepNotes.getOrNull(o.cursor - 1)
            return startLive(note?.id)
        }
        val items = if (o.kind == MenuKind.IDLE) menu.idle else menu.live
        return when (items.getOrNull(o.cursor)?.id) {
            "start" -> if (prepNotes.isEmpty()) startLive(null) else { overlay = Overlay.Menu(MenuKind.PICKER, 0); emptyList() }
            "pause" -> { paused = !paused; listOf(SessionEffect.SetPaused(paused)) }
            "captions" -> { prefs = prefs.copy(captionsOn = !prefs.captionsOn); listOf(SessionEffect.SetCaptions(prefs.captionsOn)) }
            "cues" -> { updatePrefs(prefs.copy(cuesOn = !prefs.cuesOn)); listOf(SessionEffect.SetCues(prefs.cuesOn)) }
            "prep_note" -> { overlay = Overlay.Prep(0); emptyList() }
            "display_off" -> { overlay = Overlay.Off; emptyList() }
            "end" -> endLive()
            else -> emptyList()
        }
    }

    private fun menuTitle(kind: MenuKind) = if (kind == MenuKind.PICKER) PICKER_TITLE else LIVE_TITLE

    private fun menuLabels(kind: MenuKind): List<String> {
        val flags = mapOf("paused" to paused, "captions" to prefs.captionsOn, "cues" to prefs.cuesOn)
        return when (kind) {
            MenuKind.IDLE -> menu.idle.map { it.render(flags) }
            MenuKind.LIVE -> menu.live.map { it.render(flags) }
            MenuKind.PICKER -> listOf(SKIP_AND_START) + prepNotes.map { it.title }
        }
    }

    private fun currentShown(now: Long): Cue? = shown?.takeIf { now < shownUntil }

    private fun show(cue: Cue, now: Long) {
        shown = cue
        shownUntil = now + prefs.cueDurationMillis
    }

    private fun promote(now: Long) {
        if (overlay != null || !prefs.autoPopup || currentShown(now) != null) return
        queue.poll(now)?.let { show(it, now) }
    }
}
