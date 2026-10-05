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
    ) : ScreenModel
    data class CueDetail(val cue: Cue, val page: Int) : ScreenModel
    data class Menu(val title: String, val items: List<String>, val cursor: Int) : ScreenModel
    data class PrepNoteView(val title: String, val text: String, val page: Int) : ScreenModel
    data object ConfirmEnd : ScreenModel
}

/** Screens the wearer opened; drawn at CONVERSATE_INTERACTIVE and never coalesced away. */
val ScreenModel.isInteractive: Boolean
    get() = this is ScreenModel.CueDetail || this is ScreenModel.Menu ||
        this is ScreenModel.PrepNoteView || this is ScreenModel.ConfirmEnd

data class PrepNoteRef(val id: String, val title: String, val text: String)

data class ConversatePrefs(
    val captionsOn: Boolean = true,
    val cuesOn: Boolean = true,
    val autoPopup: Boolean = true,
    val cueDurationMillis: Long = 6_000,
)

sealed interface SessionEffect {
    data class Start(val prepNoteId: String?) : SessionEffect
    data object End : SessionEffect
    data class SetPaused(val paused: Boolean) : SessionEffect
    data class SetCaptions(val on: Boolean) : SessionEffect
    data class SetCues(val on: Boolean) : SessionEffect
}
