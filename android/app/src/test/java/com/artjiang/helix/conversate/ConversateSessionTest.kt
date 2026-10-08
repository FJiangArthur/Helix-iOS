package com.artjiang.helix.conversate

import com.artjiang.helix.conversate.ConversateIntent.BACK
import com.artjiang.helix.conversate.ConversateIntent.MENU
import com.artjiang.helix.conversate.ConversateIntent.NEXT
import com.artjiang.helix.conversate.ConversateIntent.PREV
import com.artjiang.helix.conversate.ConversateIntent.SELECT
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateSessionTest {
    private var now = 0L
    private fun session(prefs: ConversatePrefs = ConversatePrefs(), pages: Int = 1) =
        ConversateSession(MenuSpec.load(), { now }, prefs, detailPageCount = { pages })
    private fun cue(id: Long, type: CueType = CueType.CONCEPT) = Cue(id, type, "T$id", "B$id", createdAtMillis = now)

    @Test
    fun `idle menu starts a session without prep notes`() {
        val s = session()
        s.onIntent(MENU)
        assertEquals(
            ScreenModel.Menu("HELIX", listOf("Start session", "Ask ChatGPT", "News", "X posts", "To-dos", "Omi", "Mode", "Display"), 0),
            s.screen(),
        )
        assertTrue(s.selectContext)
        assertEquals(listOf(SessionEffect.Start(null)), s.onIntent(SELECT))
        assertTrue(s.isLive)
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `start with prep notes shows picker`() {
        val s = session()
        s.setPrepNotes(listOf(PrepNoteRef("n1", "Acme call", "context")))
        s.onIntent(MENU); s.onIntent(SELECT)
        assertEquals(ScreenModel.Menu("PREP NOTE", listOf("Skip & start", "Acme call"), 0), s.screen())
        s.onIntent(NEXT)
        assertEquals(listOf(SessionEffect.Start("n1")), s.onIntent(SELECT))
    }

    @Test
    fun `cue pops, dwells, then collapses to captions`() {
        val s = session(); s.startLive(null)
        s.onCaptionLines(listOf("hello"))
        s.onCue(cue(1))
        assertEquals(cue(1), (s.screen() as ScreenModel.Live).cue)
        now += 6_001; s.tick()
        val live = s.screen() as ScreenModel.Live
        assertEquals(null, live.cue)
        assertEquals(listOf("hello"), live.captionLines)
    }

    @Test
    fun `auto popup off collapses cues to a count`() {
        val s = session(ConversatePrefs(autoPopup = false)); s.startLive(null)
        s.onCue(cue(1)); s.onCue(cue(2))
        assertEquals(2, (s.screen() as ScreenModel.Live).pendingCount)
        s.onIntent(SELECT)
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `next on a cue opens paged detail and back returns`() {
        val s = session(pages = 2); s.startLive(null)
        s.onCue(cue(1))
        s.onIntent(NEXT)
        assertEquals(ScreenModel.CueDetail(cue(1), 0), s.screen())
        s.onIntent(NEXT); assertEquals(1, (s.screen() as ScreenModel.CueDetail).page)
        s.onIntent(NEXT); assertEquals(1, (s.screen() as ScreenModel.CueDetail).page)
        s.onIntent(BACK)
        assertEquals(null, (s.screen() as ScreenModel.Live).cue)
    }

    @Test
    fun `cues never interrupt an open menu`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        s.onCue(cue(1, CueType.ANSWER))
        assertTrue(s.screen() is ScreenModel.Menu)
        s.onIntent(BACK)
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `answer preempts a shown concept`() {
        val s = session(); s.startLive(null)
        s.onCue(cue(1)); s.onCue(cue(2, CueType.ANSWER))
        assertEquals(2L, (s.screen() as ScreenModel.Live).cue?.id)
        now += 6_001; s.tick()
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `double back ends, timeout cancels`() {
        val s = session(); s.startLive(null)
        s.onIntent(BACK)
        assertEquals(ScreenModel.ConfirmEnd, s.screen())
        now += 3_001; s.tick()
        assertTrue(s.screen() is ScreenModel.Live)
        s.onIntent(BACK)
        now += 500
        assertEquals(listOf(SessionEffect.End), s.onIntent(BACK))
        assertFalse(s.isLive)
        assertEquals(ScreenModel.Blank, s.screen())
    }

    @Test
    fun `live menu toggles emit effects and relabel`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        assertEquals(listOf(SessionEffect.SetPaused(true)), s.onIntent(SELECT))
        assertEquals("Resume", (s.screen() as ScreenModel.Menu).items[0])
        s.onIntent(NEXT)
        assertEquals(listOf(SessionEffect.SetCaptions(false)), s.onIntent(SELECT))
        repeat(20) { s.onIntent(NEXT) }
        assertEquals(12, (s.screen() as ScreenModel.Menu).cursor)
        assertEquals(listOf(SessionEffect.End), s.onIntent(SELECT))
    }

    @Test
    fun `cues off drops incoming cues`() {
        val s = session(ConversatePrefs(cuesOn = false)); s.startLive(null)
        s.onCue(cue(1))
        assertEquals(null, (s.screen() as ScreenModel.Live).cue)
    }

    @Test
    fun `captions off and nothing to show blanks the lens`() {
        val s = session(ConversatePrefs(captionsOn = false)); s.startLive(null)
        s.onCaptionLines(listOf("x"))
        assertEquals(ScreenModel.Blank, s.screen())
    }

    @Test
    fun `display off blanks until any intent`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        repeat(11) { s.onIntent(NEXT) }
        s.onIntent(SELECT)
        assertEquals(ScreenModel.Blank, s.screen())
        s.onIntent(PREV)
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `prep note opens paged view`() {
        val s = session(); s.setPrepNotes(listOf(PrepNoteRef("n1", "Acme", "Ctx")))
        s.startLive("n1")
        s.onIntent(MENU); repeat(3) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        assertEquals(ScreenModel.PrepNoteView("Acme", "Ctx", 0), s.screen())
        s.onIntent(BACK)
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `head movement neither wakes display off nor cancels end confirm`() {
        val s = session(); s.startLive(null)
        s.onIntent(BACK)
        s.onIntent(ConversateIntent.HEAD_DOWN)
        assertEquals(ScreenModel.ConfirmEnd, s.screen())
        now += 500
        s.onIntent(PREV)
        s.onIntent(MENU); repeat(11) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        s.onIntent(ConversateIntent.HEAD_UP)
        assertEquals(ScreenModel.Blank, s.screen())
    }

    @Test
    fun `phone setMode moves the mode picker cursor`() {
        val s = session()
        s.setMode(HelixMode.OMI)
        s.onIntent(MENU); repeat(6) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        assertEquals(ScreenModel.Menu("MODE", listOf("Phone mic", "Omi pendant", "Display only"), 1), s.screen())
        assertTrue(s.selectContext)
    }

    @Test
    fun `start in display only opens the to-do dashboard instead of listening`() {
        val s = session()
        s.setMode(HelixMode.DISPLAY_ONLY)
        s.onIntent(MENU)
        assertEquals(listOf(SessionEffect.RequestPanel("todos")), s.onIntent(SELECT))
        assertFalse(s.isLive)
        assertEquals("TO-DO", (s.screen() as ScreenModel.Panel).title)
        s.onIntent(BACK)
        assertEquals(0, (s.screen() as ScreenModel.Menu).cursor)
    }

    @Test
    fun `display picker updates session prefs and live caption rows`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU); repeat(10) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        assertEquals(listOf(SessionEffect.SetPref("captionLines", "2")), s.onIntent(SELECT))
        s.onIntent(BACK); s.onIntent(BACK)
        s.onCaptionLines(listOf("a"))
        assertEquals(2, (s.screen() as ScreenModel.Live).captionRows)
    }

    @Test
    fun `phone prefs show in the display picker labels`() {
        val s = session(ConversatePrefs(captionLines = 3, brightness = 2, cueDurationMillis = 15_000, captionsOn = false))
        s.onIntent(MENU); repeat(7) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        assertEquals(
            listOf("Caption lines: 3", "Cue time: 15s", "Brightness: 2", "Captions: off"),
            (s.screen() as ScreenModel.Menu).items,
        )
    }

    @Test
    fun `panel detail pages and returns to the panel`() {
        val s = ConversateSession(MenuSpec.load(), { now }, textPageCount = { 3 })
        s.onIntent(MENU); repeat(2) { s.onIntent(NEXT) }
        assertEquals(listOf(SessionEffect.RequestPanel("news")), s.onIntent(SELECT))
        assertTrue(s.selectContext)
        s.setPanelRows("news", listOf(PanelRow("n1", "A", "a"), PanelRow("n2", "B", "b")))
        s.onIntent(NEXT); s.onIntent(SELECT)
        assertEquals(ScreenModel.PanelDetail("B", "b", 0), s.screen())
        repeat(5) { s.onIntent(NEXT) }
        assertEquals(2, (s.screen() as ScreenModel.PanelDetail).page)
        s.onIntent(BACK)
        assertEquals(ScreenModel.Panel("NEWS", listOf("A", "B"), 1), s.screen())
    }

    @Test
    fun `replacing panel rows clamps the cursor and empty select is a no-op`() {
        val s = session()
        s.onIntent(MENU); repeat(5) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        s.setPanelRows("omi", listOf(PanelRow("1", "A", ""), PanelRow("2", "B", ""), PanelRow("3", "C", "")))
        repeat(2) { s.onIntent(NEXT) }
        s.setPanelRows("omi", listOf(PanelRow("1", "A", "")))
        assertEquals(0, (s.screen() as ScreenModel.Panel).cursor)
        s.setPanelRows("omi", emptyList())
        assertEquals(emptyList<SessionEffect>(), s.onIntent(SELECT))
        assertEquals(ScreenModel.Panel("OMI", listOf("Nothing here"), 0), s.screen())
    }

    @Test
    fun `ask text outside the ask screen is ignored`() {
        val s = session()
        assertEquals(emptyList<SessionEffect>(), s.onAskText("hello"))
        assertFalse(s.isAskListening)
        s.onIntent(MENU); s.onIntent(NEXT); s.onIntent(SELECT)
        assertTrue(s.isAskListening)
        assertEquals(ScreenModel.Ask, s.screen())
        assertEquals(listOf(SessionEffect.AskQuestion("hi")), s.onAskText("  hi "))
        assertFalse(s.isAskListening)
    }

    @Test
    fun `live ask closes back to captions`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU); repeat(4) { s.onIntent(NEXT) }
        assertEquals(listOf(SessionEffect.AskListen), s.onIntent(SELECT))
        s.onAskText("q")
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `showAnswer while the ask screen is open cancels the ask first`() {
        val s = session()
        assertEquals(emptyList<SessionEffect>(), s.showAnswer(cue(8, CueType.ANSWER)))
        s.onIntent(BACK)
        s.onIntent(MENU); s.onIntent(NEXT)
        assertEquals(listOf(SessionEffect.AskListen), s.onIntent(SELECT))
        assertEquals(listOf(SessionEffect.AskCancel), s.showAnswer(cue(9, CueType.ANSWER)))
        assertFalse(s.isAskListening)
        assertEquals(ScreenModel.CueDetail(cue(9, CueType.ANSWER), 0), s.screen())
    }

    @Test
    fun `starting or ending a session while asking cancels the ask`() {
        val s = session()
        s.onIntent(MENU); s.onIntent(NEXT); s.onIntent(SELECT)
        assertTrue(s.isAskListening)
        assertEquals(listOf(SessionEffect.Start(null), SessionEffect.AskCancel), s.startLive(null))
        assertFalse(s.isAskListening)
        s.onIntent(MENU); repeat(4) { s.onIntent(NEXT) }
        assertEquals(listOf(SessionEffect.AskListen), s.onIntent(SELECT))
        assertEquals(listOf(SessionEffect.End, SessionEffect.AskCancel), s.endLive())
        assertFalse(s.isAskListening)
        assertEquals(listOf(SessionEffect.End), s.endLive())
    }

    @Test
    fun `showAnswer when idle opens a detail card and back clears it`() {
        val s = session()
        s.showAnswer(cue(9, CueType.ANSWER))
        assertEquals(ScreenModel.CueDetail(cue(9, CueType.ANSWER), 0), s.screen())
        s.onIntent(MENU)
        assertEquals("Start session", (s.screen() as ScreenModel.Menu).items[0])
        s.onIntent(BACK)
        assertEquals(ScreenModel.Blank, s.screen())
        s.showAnswer(cue(9, CueType.ANSWER))
        s.onIntent(BACK)
        assertEquals(ScreenModel.Blank, s.screen())
    }
}
