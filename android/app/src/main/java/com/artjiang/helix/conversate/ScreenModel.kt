// What Conversate wants on the lens, independent of device (spec §4.2).
package com.artjiang.helix.conversate

sealed interface ScreenModel {
    data object Blank : ScreenModel
    data class Live(
        val cue: Cue?,
        val pendingCount: Int,
        val captionLines: List<String>,
        val captionsOn: Boolean,
        val paused: Boolean,
        /** Caption rows the wearer chose (contract 0.3 §4, 2..5); caps captions-only and pending layouts. */
        val captionRows: Int = ConversatePrefs.DEFAULT_CAPTION_LINES,
    ) : ScreenModel
    data class CueDetail(val cue: Cue, val page: Int) : ScreenModel
    data class Menu(val title: String, val items: List<String>, val cursor: Int) : ScreenModel
    data class PrepNoteView(val title: String, val text: String, val page: Int) : ScreenModel
    data object ConfirmEnd : ScreenModel

    /** Dashboard list (contract 0.3 §5); items are already rendered ("[x] ..." for to-dos). */
    data class Panel(val title: String, val items: List<String>, val cursor: Int) : ScreenModel
    data class PanelDetail(val title: String, val text: String, val page: Int) : ScreenModel

    /** Waiting for the wearer's spoken question (contract 0.3 §6). */
    data object Ask : ScreenModel
}

/** Screens the wearer opened; drawn at CONVERSATE_INTERACTIVE and never coalesced away. */
val ScreenModel.isInteractive: Boolean
    get() = this is ScreenModel.CueDetail || this is ScreenModel.Menu ||
        this is ScreenModel.PrepNoteView || this is ScreenModel.ConfirmEnd ||
        this is ScreenModel.Panel || this is ScreenModel.PanelDetail || this is ScreenModel.Ask

data class PrepNoteRef(val id: String, val title: String, val text: String)

data class ConversatePrefs(
    val captionsOn: Boolean = true,
    val cuesOn: Boolean = true,
    val autoPopup: Boolean = true,
    val cueDurationMillis: Long = 6_000,
    val captionLines: Int = DEFAULT_CAPTION_LINES,
    val brightness: Int = DEFAULT_BRIGHTNESS,
) {
    companion object {
        const val DEFAULT_CAPTION_LINES = 5
        const val DEFAULT_BRIGHTNESS = 3
        val CAPTION_LINE_RANGE = 2..5
        val BRIGHTNESS_RANGE = 1..4

        /** Contract 0.3 §4: levels 1..4 map onto the G1's 0..63 scale as 10/20/30/42. */
        fun g1BrightnessByte(level: Int): Int {
            val l = level.coerceIn(BRIGHTNESS_RANGE)
            return l * 10 + if (l == 4) 2 else 0
        }
    }
}

/** How Helix listens (contract 0.3 §3). Names are the shared picker ids. */
enum class HelixMode { PHONE_MIC, OMI, DISPLAY_ONLY }

/** One dashboard row (contract 0.3 §5). [done] only matters for to-dos. */
data class PanelRow(val id: String, val title: String, val detail: String = "", val done: Boolean = false)

sealed interface SessionEffect {
    data class Start(val prepNoteId: String?) : SessionEffect
    data object End : SessionEffect
    data class SetPaused(val paused: Boolean) : SessionEffect
    data class SetCaptions(val on: Boolean) : SessionEffect
    data class SetCues(val on: Boolean) : SessionEffect
    data class SetMode(val mode: HelixMode) : SessionEffect

    /** Display picker change; [value] is the picker value as text ("2", "10", "off"). */
    data class SetPref(val id: String, val value: String) : SessionEffect
    data class RequestPanel(val kind: String) : SessionEffect
    data class ToggleTodo(val id: String, val done: Boolean) : SessionEffect
    data object AskListen : SessionEffect
    data class AskQuestion(val text: String) : SessionEffect
    data object AskCancel : SessionEffect
}

/** ASCII-only HUD glyphs until the G1 font's coverage is confirmed on hardware. */
object HudGlyphs {
    const val CUE = "*"
    const val CURSOR = ">"
    const val MORE = ">>"
    const val RULE = "- - - - - - - - - -"
    const val PAUSED = "||"
}
