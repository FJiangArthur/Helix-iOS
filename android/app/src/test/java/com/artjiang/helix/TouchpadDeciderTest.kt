package com.artjiang.helix

import com.artjiang.helix.g1.G1TouchpadSide
import org.junit.Assert.assertEquals
import org.junit.Test

class TouchpadDeciderTest {

    @Test
    fun `with an answer on screen index 1 pages left and right`() {
        assertEquals(
            TouchpadEffect.ChangePage(-1),
            TouchpadDecider.decide(1, G1TouchpadSide.LEFT, hasActiveAnswer = true),
        )
        assertEquals(
            TouchpadEffect.ChangePage(1),
            TouchpadDecider.decide(1, G1TouchpadSide.RIGHT, hasActiveAnswer = true),
        )
    }

    @Test
    fun `with no answer the right pad triggers manual question detection`() {
        assertEquals(
            TouchpadEffect.TriggerManualQuestion,
            TouchpadDecider.decide(1, G1TouchpadSide.RIGHT, hasActiveAnswer = false),
        )
    }

    @Test
    fun `with no answer the left pad pauses or resumes transcription`() {
        assertEquals(
            TouchpadEffect.ToggleListening,
            TouchpadDecider.decide(1, G1TouchpadSide.LEFT, hasActiveAnswer = false),
        )
    }

    @Test
    fun `evenAI start triggers manual detection from either side`() {
        assertEquals(
            TouchpadEffect.TriggerManualQuestion,
            TouchpadDecider.decide(23, G1TouchpadSide.LEFT, hasActiveAnswer = false),
        )
        assertEquals(
            TouchpadEffect.TriggerManualQuestion,
            TouchpadDecider.decide(23, G1TouchpadSide.RIGHT, hasActiveAnswer = true),
        )
    }

    @Test
    fun `evenAI record over stops listening`() {
        assertEquals(
            TouchpadEffect.StopListening,
            TouchpadDecider.decide(24, G1TouchpadSide.RIGHT, hasActiveAnswer = false),
        )
    }

    @Test
    fun `index 0 clears the HUD`() {
        assertEquals(
            TouchpadEffect.ClearHud,
            TouchpadDecider.decide(0, G1TouchpadSide.LEFT, hasActiveAnswer = true),
        )
    }

    @Test
    fun `head gestures produce no app-shell effect`() {
        assertEquals(TouchpadEffect.None, TouchpadDecider.decide(2, G1TouchpadSide.LEFT, false))
        assertEquals(TouchpadEffect.None, TouchpadDecider.decide(3, G1TouchpadSide.LEFT, false))
    }

    @Test
    fun `unknown indices are ignored`() {
        assertEquals(TouchpadEffect.None, TouchpadDecider.decide(99, G1TouchpadSide.RIGHT, true))
    }
}
