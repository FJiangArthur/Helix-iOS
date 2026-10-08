// Conversate state machine (spec §4.2, contract 0.3). Pure and single-threaded:
// the controller calls it from one coroutine context and asks for screen()
// after every input. Timers are driven by tick() against the injected clock.
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
        const val LIVE_TITLE = "HELIX"
        const val PICKER_TITLE = "PREP NOTE"
        const val SKIP_AND_START = "Skip & start"
        const val NO_PREP_NOTE = "No prep note for this session."
        const val EMPTY_PANEL = "Nothing here"
        const val TODOS = "todos"
        private const val MODE_PICKER = "mode"
        private const val DISPLAY_PICKER = "display"
    }

    private enum class MenuKind { IDLE, LIVE, PICKER, MODE, DISPLAY }

    private sealed interface Overlay {
        /** [parent] is the menu a child picker was opened from (contract 0.3 §2). */
        data class Menu(val kind: MenuKind, val cursor: Int, val parent: Menu? = null) : Overlay
        data class Detail(val cue: Cue, val page: Int) : Overlay
        data class Prep(val page: Int) : Overlay
        data class Confirm(val until: Long) : Overlay
        data object Off : Overlay
        data class Panel(val kind: String, val cursor: Int, val parent: Menu) : Overlay
        data class PanelDetail(val panel: Panel, val title: String, val text: String, val page: Int) : Overlay
        data class Ask(val parent: Menu) : Overlay
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
    private val panelRows = mutableMapOf<String, List<PanelRow>>()

    var isLive: Boolean = false
        private set

    /** Session `mode` (contract 0.3 §3); the phone sets it with [setMode]. */
    var mode: HelixMode = HelixMode.PHONE_MIC
        private set

    /** True while a list is open: G1 long-press means SELECT, not MENU. */
    val selectContext: Boolean get() = overlay is Overlay.Menu || overlay is Overlay.Panel

    /** True while the Ask screen waits for the wearer's question. */
    val isAskListening: Boolean get() = overlay is Overlay.Ask

    val currentPrefs: ConversatePrefs get() = prefs

    fun setPrepNotes(notes: List<PrepNoteRef>) { prepNotes = notes }

    fun updatePrefs(prefs: ConversatePrefs) {
        this.prefs = prefs
        if (!prefs.cuesOn) { queue.clear(); shown = null }
    }

    fun setPaused(paused: Boolean) { this.paused = paused }

    fun setMode(mode: HelixMode) { this.mode = mode }

    /** Replaces one panel's rows; an open panel keeps its cursor, clamped. */
    fun setPanelRows(kind: String, rows: List<PanelRow>) {
        panelRows[kind] = rows
        when (val o = overlay) {
            is Overlay.Panel -> if (o.kind == kind) overlay = o.copy(cursor = clampPanel(o.kind, o.cursor))
            is Overlay.PanelDetail -> if (o.panel.kind == kind) {
                overlay = o.copy(panel = o.panel.copy(cursor = clampPanel(kind, o.panel.cursor)))
            }
            else -> Unit
        }
    }

    fun panelRows(kind: String): List<PanelRow> = panelRows[kind].orEmpty()

    /**
     * The next final transcript while the Ask screen is open (contract 0.3 §6).
     * Closes the overlay entirely; ignored anywhere else.
     */
    fun onAskText(text: String): List<SessionEffect> {
        if (overlay !is Overlay.Ask) return emptyList()
        val question = text.trim()
        if (question.isEmpty()) return emptyList()
        overlay = null
        promote(clock())
        return listOf(SessionEffect.AskQuestion(question))
    }

    /** An answer outside a live session (Display-only / idle): shown as a detail card. */
    fun showAnswer(cue: Cue) {
        overlay = Overlay.Detail(cue, 0)
    }

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

    private fun rootMenu() = Overlay.Menu(if (isLive) MenuKind.LIVE else MenuKind.IDLE, 0)

    private fun handle(intent: ConversateIntent): List<SessionEffect> {
        // No head-up dashboard yet (Plan C): head movement must not act as a
        // tap — it would wake "Display off" or cancel "End session?".
        if (intent == ConversateIntent.HEAD_UP || intent == ConversateIntent.HEAD_DOWN) return emptyList()
        val now = clock()
        when (val o = overlay) {
            Overlay.Off -> { overlay = null; return emptyList() }
            is Overlay.Menu -> return onMenuIntent(o, intent)
            is Overlay.Panel -> return onPanelIntent(o, intent)
            is Overlay.PanelDetail -> {
                when (intent) {
                    ConversateIntent.NEXT ->
                        overlay = o.copy(page = (o.page + 1).coerceAtMost(textPageCount("${o.title}\n${o.text}") - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK, ConversateIntent.MENU -> overlay = o.panel
                    else -> Unit
                }
                return emptyList()
            }
            is Overlay.Ask -> {
                if (intent == ConversateIntent.BACK || intent == ConversateIntent.MENU) {
                    overlay = o.parent
                    return listOf(SessionEffect.AskCancel)
                }
                return emptyList()
            }
            is Overlay.Detail -> {
                when (intent) {
                    ConversateIntent.NEXT -> overlay = o.copy(page = (o.page + 1).coerceAtMost(detailPageCount(o.cue) - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK -> { overlay = null; shown = null; promote(now) }
                    ConversateIntent.MENU -> overlay = rootMenu()
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
                    ConversateIntent.MENU -> overlay = rootMenu()
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
            overlay = rootMenu()
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
            is Overlay.Panel -> ScreenModel.Panel(panelTitle(o.kind), panelItems(o.kind), o.cursor)
            is Overlay.PanelDetail -> ScreenModel.PanelDetail(o.title, o.text, o.page)
            is Overlay.Ask -> ScreenModel.Ask
            null -> liveScreen(now)
        }
    }

    private fun liveScreen(now: Long): ScreenModel {
        if (!isLive) return ScreenModel.Blank
        val cue = currentShown(now)
        val pending = if (cue == null && !prefs.autoPopup) queue.count(now) else 0
        if (!paused && cue == null && pending == 0 && !prefs.captionsOn) return ScreenModel.Blank
        return ScreenModel.Live(cue, pending, captions, prefs.captionsOn, paused, prefs.captionLines)
    }

    private fun onMenuIntent(o: Overlay.Menu, intent: ConversateIntent): List<SessionEffect> {
        val labels = menuLabels(o.kind)
        when (intent) {
            ConversateIntent.NEXT -> overlay = o.copy(cursor = (o.cursor + 1).coerceAtMost(labels.size - 1))
            ConversateIntent.PREV -> overlay = o.copy(cursor = (o.cursor - 1).coerceAtLeast(0))
            ConversateIntent.BACK, ConversateIntent.MENU ->
                overlay = when {
                    o.parent != null -> o.parent
                    o.kind == MenuKind.PICKER -> Overlay.Menu(MenuKind.IDLE, 0)
                    else -> null
                }
            ConversateIntent.SELECT -> return activate(o)
            else -> Unit
        }
        return emptyList()
    }

    private fun onPanelIntent(o: Overlay.Panel, intent: ConversateIntent): List<SessionEffect> {
        when (intent) {
            ConversateIntent.NEXT -> overlay = o.copy(cursor = clampPanel(o.kind, o.cursor + 1))
            ConversateIntent.PREV -> overlay = o.copy(cursor = clampPanel(o.kind, o.cursor - 1))
            ConversateIntent.BACK, ConversateIntent.MENU -> overlay = o.parent
            ConversateIntent.SELECT -> {
                val rows = panelRows(o.kind)
                val row = rows.getOrNull(o.cursor) ?: return emptyList()
                if (o.kind == TODOS) {
                    val flipped = row.copy(done = !row.done)
                    panelRows[o.kind] = rows.map { if (it.id == row.id) flipped else it }
                    return listOf(SessionEffect.ToggleTodo(row.id, flipped.done))
                }
                overlay = Overlay.PanelDetail(o, row.title, row.detail, 0)
            }
            else -> Unit
        }
        return emptyList()
    }

    private fun activate(o: Overlay.Menu): List<SessionEffect> {
        when (o.kind) {
            MenuKind.PICKER -> {
                val note = if (o.cursor == 0) null else prepNotes.getOrNull(o.cursor - 1)
                return startLive(note?.id)
            }
            MenuKind.MODE -> {
                val id = picker(MODE_PICKER)?.items?.getOrNull(o.cursor)?.id ?: return emptyList()
                val chosen = HelixMode.entries.firstOrNull { it.name == id } ?: return emptyList()
                mode = chosen
                overlay = o.parent
                return listOf(SessionEffect.SetMode(chosen))
            }
            MenuKind.DISPLAY -> {
                val item = picker(DISPLAY_PICKER)?.items?.getOrNull(o.cursor) ?: return emptyList()
                val values = item.valueStrings
                if (values.isEmpty()) return emptyList()
                val next = values[(values.indexOf(prefValue(item.id)) + 1) % values.size]
                applyPref(item.id, next)
                return listOf(SessionEffect.SetPref(item.id, next))
            }
            MenuKind.IDLE, MenuKind.LIVE -> Unit
        }
        val items = if (o.kind == MenuKind.IDLE) menu.idle else menu.live
        val id = items.getOrNull(o.cursor)?.id
        if (id != null && id in menu.panels) {
            overlay = Overlay.Panel(id, 0, o)
            return listOf(SessionEffect.RequestPanel(id))
        }
        // Display-only has no mic: "Start session" opens the to-do dashboard instead.
        if (id == "start" && mode == HelixMode.DISPLAY_ONLY && TODOS in menu.panels) {
            overlay = Overlay.Panel(TODOS, 0, o)
            return listOf(SessionEffect.RequestPanel(TODOS))
        }
        return when (id) {
            "start" -> if (prepNotes.isEmpty()) startLive(null) else { overlay = Overlay.Menu(MenuKind.PICKER, 0); emptyList() }
            "pause" -> { paused = !paused; listOf(SessionEffect.SetPaused(paused)) }
            "captions" -> { prefs = prefs.copy(captionsOn = !prefs.captionsOn); listOf(SessionEffect.SetCaptions(prefs.captionsOn)) }
            "cues" -> { updatePrefs(prefs.copy(cuesOn = !prefs.cuesOn)); listOf(SessionEffect.SetCues(prefs.cuesOn)) }
            "prep_note" -> { overlay = Overlay.Prep(0); emptyList() }
            "display_off" -> { overlay = Overlay.Off; emptyList() }
            "end" -> endLive()
            "ask" -> { overlay = Overlay.Ask(o); listOf(SessionEffect.AskListen) }
            "mode" -> {
                val index = picker(MODE_PICKER)?.items?.indexOfFirst { it.id == mode.name } ?: 0
                overlay = Overlay.Menu(MenuKind.MODE, index.coerceAtLeast(0), parent = o)
                emptyList()
            }
            "display" -> { overlay = Overlay.Menu(MenuKind.DISPLAY, 0, parent = o); emptyList() }
            else -> emptyList()
        }
    }

    private fun picker(id: String): PickerSpec? = menu.pickers[id]

    /** Current value of a display picker item, as the picker's value text. */
    private fun prefValue(id: String): String = when (id) {
        "captionLines" -> prefs.captionLines.toString()
        "cueSeconds" -> (prefs.cueDurationMillis / 1_000L).toString()
        "brightness" -> prefs.brightness.toString()
        "captions" -> if (prefs.captionsOn) "on" else "off"
        else -> ""
    }

    private fun applyPref(id: String, value: String) {
        val p = prefs
        updatePrefs(
            when (id) {
                "captionLines" -> p.copy(captionLines = value.toIntOrNull() ?: p.captionLines)
                "cueSeconds" -> p.copy(cueDurationMillis = (value.toLongOrNull() ?: (p.cueDurationMillis / 1_000L)) * 1_000L)
                "brightness" -> p.copy(brightness = value.toIntOrNull() ?: p.brightness)
                "captions" -> p.copy(captionsOn = value == "on")
                else -> p
            },
        )
    }

    private fun menuTitle(kind: MenuKind) = when (kind) {
        MenuKind.PICKER -> PICKER_TITLE
        MenuKind.MODE -> picker(MODE_PICKER)?.title ?: "MODE"
        MenuKind.DISPLAY -> picker(DISPLAY_PICKER)?.title ?: "DISPLAY"
        MenuKind.IDLE, MenuKind.LIVE -> LIVE_TITLE
    }

    private fun menuLabels(kind: MenuKind): List<String> {
        val flags = mapOf("paused" to paused, "captions" to prefs.captionsOn, "cues" to prefs.cuesOn)
        return when (kind) {
            MenuKind.IDLE -> menu.idle.map { it.render(flags) }
            MenuKind.LIVE -> menu.live.map { it.render(flags) }
            MenuKind.PICKER -> listOf(SKIP_AND_START) + prepNotes.map { it.title }
            MenuKind.MODE -> picker(MODE_PICKER)?.items?.map { it.label }.orEmpty()
            MenuKind.DISPLAY -> picker(DISPLAY_PICKER)?.items?.map { it.renderValue(prefValue(it.id)) }.orEmpty()
        }
    }

    private fun panelTitle(kind: String) = menu.panels[kind]?.title ?: kind.uppercase()

    private fun panelItems(kind: String): List<String> {
        val rows = panelRows(kind)
        if (rows.isEmpty()) return listOf(EMPTY_PANEL)
        return if (kind == TODOS) rows.map { "${if (it.done) "[x]" else "[ ]"} ${it.title}" } else rows.map { it.title }
    }

    private fun clampPanel(kind: String, cursor: Int) = cursor.coerceIn(0, panelItems(kind).size - 1)

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
