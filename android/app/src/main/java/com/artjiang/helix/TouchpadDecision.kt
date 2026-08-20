// Pure decision layer between the G1 touchpad router and the app-shell effects
// the bridge performs. Split out so the routing rules are unit-testable without
// BLE, audio, or coroutine scaffolding.
package com.artjiang.helix

import com.artjiang.helix.g1.G1TouchpadAction
import com.artjiang.helix.g1.G1TouchpadRouter
import com.artjiang.helix.g1.G1TouchpadSide

/** What the app shell should do in response to a touchpad press. */
sealed interface TouchpadEffect {
    /** Re-push the HUD with the page index moved by [delta]. */
    data class ChangePage(val delta: Int) : TouchpadEffect

    /** Run manual question detection over the latest transcript. */
    data object TriggerManualQuestion : TouchpadEffect

    /** Stop the listening session. */
    data object StopListening : TouchpadEffect

    /** Pause or resume transcription (left pad, no answer on screen). */
    data object ToggleListening : TouchpadEffect

    /** Clear the HUD / exit the current display. */
    data object ClearHud : TouchpadEffect

    /** Nothing to do. */
    data object None : TouchpadEffect
}

object TouchpadDecider {
    /**
     * Maps an inbound notify index to an app-shell effect.
     *
     * Page navigation is only reachable while an answer is on screen — the
     * `hasActiveAnswer` flag comes from the engine's live `activeAnswer`, which
     * clears on every new final transcript, so a stale answer can never keep
     * capturing the touchpad (the iOS `EvenAI.hasActiveAnswer` bug).
     */
    fun decide(
        notifyIndex: Int,
        side: G1TouchpadSide,
        hasActiveAnswer: Boolean,
    ): TouchpadEffect = when (G1TouchpadRouter.route(notifyIndex, side, hasActiveAnswer)) {
        G1TouchpadAction.PreviousPage -> TouchpadEffect.ChangePage(-1)
        G1TouchpadAction.NextPage -> TouchpadEffect.ChangePage(1)
        G1TouchpadAction.EvenAIStart -> TouchpadEffect.TriggerManualQuestion
        G1TouchpadAction.EvenAIRecordOver -> TouchpadEffect.StopListening
        G1TouchpadAction.Exit -> TouchpadEffect.ClearHud
        // Left pad with no answer on screen: pause/resume transcription, per
        // the liveListening touchpad table in CLAUDE.md.
        is G1TouchpadAction.Unknown ->
            if (notifyIndex == 1 && side == G1TouchpadSide.LEFT && !hasActiveAnswer) {
                TouchpadEffect.ToggleListening
            } else {
                TouchpadEffect.None
            }

        G1TouchpadAction.HeadUp, G1TouchpadAction.HeadDown -> TouchpadEffect.None
    }
}
