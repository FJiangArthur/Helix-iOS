package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateControllerTest {
    private class Rig(scope: TestScope) {
        val sent = mutableListOf<String>()
        val effects = mutableListOf<SessionEffect>()
        var clears = 0
        val controller = ConversateController(
            scope = scope.backgroundScope,
            sendScreen = { p -> sent += String(p.first().copyOfRange(9, p.first().size)); G1ScreenDeliveryOutcome.deliveredToBoth(p.size) },
            clearScreen = { clears++ },
            arbiter = HudArbiter { scope.testScheduler.currentTime },
            classify = { _, _ -> """{"cues":[]}""" },
            clock = { scope.testScheduler.currentTime },
            onEffect = { effects += it },
        )
    }

    @Test
    fun `disabled controller consumes nothing`() = runTest {
        val rig = Rig(this)
        assertFalse(rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT)))
    }

    @Test
    fun `long press opens menu, select starts, captions reach the lens`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        assertTrue(rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT)))
        assertTrue(rig.controller.handleTouchpad(G1TouchpadFrame(24, G1TouchpadSide.LEFT)))
        advanceTimeBy(500)
        assertTrue(rig.sent.last().startsWith("HELIX"))
        rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT))
        assertEquals(listOf<SessionEffect>(SessionEffect.Start(null)), rig.effects)
        rig.controller.onSegment(TranscriptSegment("hello world", false, 0))
        advanceTimeBy(2_000)
        assertEquals("hello world", rig.sent.last())
    }

    @Test
    fun `answer while live becomes an answer cue`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.offerExternal("Q3 revenue was 4M.", HudArbiter.Priority.ANSWER)
        advanceTimeBy(1_000)
        assertTrue(rig.sent.last().startsWith("* ANSWER"))
    }

    @Test
    fun `end clears the lens`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.onSegment(TranscriptSegment("hi", true, 0)); advanceTimeBy(1_000)
        rig.controller.end(); advanceTimeBy(1_000)
        assertEquals(1, rig.clears)
        assertFalse(rig.controller.isLive.value)
    }

    @Test
    fun `pause from glasses menu and from phone share one state`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.intent(ConversateIntent.MENU)
        rig.controller.intent(ConversateIntent.SELECT)
        assertTrue(rig.controller.paused.value)
        rig.controller.setPaused(false)
        assertFalse(rig.controller.paused.value)
        assertEquals(SessionEffect.SetPaused(false), rig.effects.last())
        rig.controller.end()
        assertFalse(rig.controller.paused.value)
    }

    @Test
    fun `changing prefs while disabled sends nothing`() = runTest {
        val rig = Rig(this)
        rig.controller.setPrefs(ConversatePrefs(captionsOn = false))
        advanceTimeBy(1_000)
        assertEquals(0, rig.clears)
        assertEquals(emptyList<String>(), rig.sent)
    }

    @Test
    fun `multi-line answers never exceed five lens lines`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.offerExternal("Point one.\nPoint two.\nPoint three.\nPoint four.", HudArbiter.Priority.ANSWER)
        advanceTimeBy(1_000)
        assertTrue(rig.sent.last().lines().size <= 5)
    }

    @Test
    fun `redraw resends the current screen`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.intent(ConversateIntent.MENU)
        advanceTimeBy(500)
        val before = rig.sent.size
        rig.controller.redraw()
        advanceTimeBy(500)
        assertEquals(before + 1, rig.sent.size)
    }

    @Test
    fun `ring hold opens the menu and ring tap selects`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.handleRing(com.artjiang.helix.ring.R1Gesture.HOLD)
        assertTrue(rig.controller.screen.value is ScreenModel.Menu)
        rig.controller.handleRing(com.artjiang.helix.ring.R1Gesture.HOLD_RELEASE)
        rig.controller.handleRing(com.artjiang.helix.ring.R1Gesture.TAP)
        assertEquals(listOf<SessionEffect>(SessionEffect.Start(null)), rig.effects)
    }

    @Test
    fun `ring swipe and touchpad tap for the same move count once`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.intent(ConversateIntent.MENU)
        rig.controller.handleRing(com.artjiang.helix.ring.R1Gesture.SWIPE_FORWARD)
        rig.controller.handleTouchpad(G1TouchpadFrame(1, G1TouchpadSide.RIGHT))
        assertEquals(1, (rig.controller.screen.value as ScreenModel.Menu).cursor)
    }

    @Test
    fun `display picker change is reported with the session prefs`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.intent(ConversateIntent.MENU)
        repeat(7) { rig.controller.intent(ConversateIntent.NEXT) }
        rig.controller.intent(ConversateIntent.SELECT)
        repeat(2) { rig.controller.intent(ConversateIntent.NEXT) }
        rig.controller.intent(ConversateIntent.SELECT)
        assertEquals(SessionEffect.SetPref("brightness", "4"), rig.effects.last())
        assertEquals(4, rig.controller.currentPrefs.brightness)
    }

    @Test
    fun `phone mode change shows in the glasses picker`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.setMode(HelixMode.DISPLAY_ONLY)
        rig.controller.intent(ConversateIntent.MENU)
        repeat(6) { rig.controller.intent(ConversateIntent.NEXT) }
        rig.controller.intent(ConversateIntent.SELECT)
        assertEquals(2, (rig.controller.screen.value as ScreenModel.Menu).cursor)
    }

    @Test
    fun `panel rows arrive after the request and render on the lens`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.intent(ConversateIntent.MENU)
        repeat(2) { rig.controller.intent(ConversateIntent.NEXT) }
        rig.controller.intent(ConversateIntent.SELECT)
        assertEquals(SessionEffect.RequestPanel("news"), rig.effects.last())
        rig.controller.setPanelRows("news", listOf(PanelRow("n1", "Fed holds rates steady", "detail")))
        advanceTimeBy(500)
        assertEquals("> Fed holds rates steady", rig.sent.last().lines()[1])
    }

    @Test
    fun `idle ask takes the next final segment and ignores partials`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.intent(ConversateIntent.MENU)
        rig.controller.intent(ConversateIntent.NEXT)
        rig.controller.intent(ConversateIntent.SELECT)
        assertEquals(SessionEffect.AskListen, rig.effects.last())
        assertTrue(rig.controller.isAskListening)
        advanceTimeBy(500)
        assertTrue(rig.sent.last().startsWith("Ask: listening..."))
        assertFalse(rig.controller.onSegment(TranscriptSegment("what is", false, 0)))
        assertTrue(rig.controller.onSegment(TranscriptSegment("What is the capital of Australia?", true, 0)))
        assertEquals(SessionEffect.AskQuestion("What is the capital of Australia?"), rig.effects.last())
        assertFalse(rig.controller.isAskListening)
    }

    @Test
    fun `answer when not live shows a detail card`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.showAnswer("Canberra is the capital.")
        advanceTimeBy(500)
        assertEquals("* ANSWER Answer\nCanberra is the capital.", rig.sent.last())
        assertTrue(rig.controller.screen.value is ScreenModel.CueDetail)
    }

    @Test
    fun `ring is ignored while conversate is disabled`() = runTest {
        val rig = Rig(this)
        rig.controller.handleRing(com.artjiang.helix.ring.R1Gesture.HOLD)
        assertEquals(ScreenModel.Blank, rig.controller.screen.value)
    }
}
