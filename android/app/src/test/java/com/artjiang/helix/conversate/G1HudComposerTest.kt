package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class G1HudComposerTest {
    private val composer = G1HudComposer()
    private fun cue(title: String = "Fed rate", body: String = "Rates held at 4.25-4.50%.", detail: String? = null) =
        Cue(1, CueType.ANSWER, title, body, detail, createdAtMillis = 0)

    @Test
    fun `live cue card layout`() {
        val f = composer.compose(ScreenModel.Live(cue(), 0, listOf("one", "two"), captionsOn = true, paused = false))!!
        assertEquals("* ANSWER  Fed rate\nRates held at 4.25-4.50%.\n\n- - - - - - - - - -\ntwo", f.text)
    }

    @Test
    fun `cue with detail shows more marker`() {
        val f = composer.compose(ScreenModel.Live(cue(detail = "long"), 0, emptyList(), true, false))!!
        assertTrue(f.text.lines()[1].endsWith(">>"))
    }

    @Test
    fun `long title truncated to the line`() {
        val f = composer.compose(ScreenModel.Live(cue(title = "X".repeat(80)), 0, emptyList(), true, false))!!
        assertTrue(f.text.lines()[0].length <= 46)
        assertTrue(f.text.lines().size <= 5)
    }

    @Test
    fun `captions only shows last five lines`() {
        val lines = (1..7).map { "line $it" }
        val f = composer.compose(ScreenModel.Live(null, 0, lines, true, false))!!
        assertEquals((3..7).joinToString("\n") { "line $it" }, f.text)
    }

    @Test
    fun `pending cues line above four captions`() {
        val f = composer.compose(ScreenModel.Live(null, 2, (1..6).map { "c$it" }, true, false))!!
        assertEquals("* 2 new cues\nc3\nc4\nc5\nc6", f.text)
    }

    @Test
    fun `paused`() {
        val f = composer.compose(ScreenModel.Live(null, 0, emptyList(), true, true))!!
        assertEquals("|| Paused\nHold left pad for menu", f.text)
    }

    @Test
    fun `menu windows four items with cursor and counter`() {
        val items = listOf("A", "B", "C", "D", "E", "F")
        val f = composer.compose(ScreenModel.Menu("CONVERSATE", items, 4))!!
        val lines = f.text.lines()
        assertEquals(3, lines.size)
        assertTrue(lines[0].startsWith("CONVERSATE") && lines[0].endsWith("5/6"))
        assertEquals(listOf("> E", "  F"), lines.drop(1))
    }

    @Test
    fun `detail paginates and reports pages`() {
        val c = cue(detail = (1..60).joinToString(" ") { "word$it" })
        val count = composer.detailPageCount(c)
        assertTrue(count >= 2)
        val f = composer.compose(ScreenModel.CueDetail(c, 1))!!
        assertEquals(2, f.page)
        assertEquals(count, f.pageCount)
    }

    @Test
    fun `prep note keeps line breaks and never exceeds five lines`() {
        val text = (1..8).joinToString("\n") { "Point $it" }
        val f = composer.compose(ScreenModel.PrepNoteView("Acme", text, 0))!!
        assertEquals(listOf("Acme", "Point 1", "Point 2", "Point 3", "Point 4"), f.text.lines())
        assertEquals(2, f.pageCount)
    }

    @Test
    fun `caption lines pref caps captions only layout`() {
        val lines = (1..7).map { "line $it" }
        for (n in 2..5) {
            val f = composer.compose(ScreenModel.Live(null, 0, lines, true, false, captionRows = n))!!
            assertEquals(((8 - n)..7).joinToString("\n") { "line $it" }, f.text)
        }
    }

    @Test
    fun `caption lines pref caps pending layout`() {
        val f2 = composer.compose(ScreenModel.Live(null, 1, (1..6).map { "c$it" }, true, false, captionRows = 2))!!
        assertEquals("* 1 new cue\nc5\nc6", f2.text)
        val f5 = composer.compose(ScreenModel.Live(null, 1, (1..6).map { "c$it" }, true, false, captionRows = 5))!!
        assertEquals("* 1 new cue\nc3\nc4\nc5\nc6", f5.text)
    }

    @Test
    fun `caption lines pref leaves the cue card unchanged`() {
        val f = composer.compose(ScreenModel.Live(cue(), 0, listOf("one", "two"), true, false, captionRows = 2))!!
        assertEquals("* ANSWER  Fed rate\nRates held at 4.25-4.50%.\n\n- - - - - - - - - -\ntwo", f.text)
    }

    @Test
    fun `panel renders header counter and four rows with cursor`() {
        val items = listOf("[ ] One", "[x] Two", "[ ] Three", "[ ] Four", "[ ] Five")
        val f = composer.compose(ScreenModel.Panel("TO-DO", items, 1))!!
        val lines = f.text.lines()
        assertEquals(5, lines.size)
        assertTrue(lines[0].startsWith("TO-DO") && lines[0].endsWith("2/5"))
        assertEquals(46, lines[0].length)
        assertEquals(listOf("  [ ] One", "> [x] Two", "  [ ] Three", "  [ ] Four"), lines.drop(1))
        val last = composer.compose(ScreenModel.Panel("TO-DO", items, 4))!!.text.lines()
        assertEquals(listOf("TO-DO", "> [ ] Five"), listOf(last[0].substringBefore(" "), last[1]))
    }

    @Test
    fun `panel truncates long rows`() {
        val f = composer.compose(ScreenModel.Panel("NEWS", listOf("N".repeat(80)), 0))!!
        assertTrue(f.text.lines()[1].length <= 46)
        assertTrue(f.text.lines()[1].endsWith("~"))
    }

    @Test
    fun `panel detail pages like a prep note`() {
        val text = (1..8).joinToString("\n") { "Point $it" }
        val f = composer.compose(ScreenModel.PanelDetail("Fed holds", text, 1))!!
        assertEquals(listOf("Point 5", "Point 6", "Point 7", "Point 8"), f.text.lines())
        assertEquals(2, f.page)
        assertEquals(2, f.pageCount)
        assertEquals(2, composer.textPageCount("Fed holds\n$text"))
    }

    @Test
    fun `ask screen`() {
        assertEquals("Ask: listening...\n\nSpeak your question\nDouble-tap to cancel", composer.compose(ScreenModel.Ask)!!.text)
    }

    @Test
    fun `blank clears`(){ assertNull(composer.compose(ScreenModel.Blank)) }

    @Test
    fun `confirm end`() {
        assertEquals("End session?\n\nDouble-tap again to end\nAny other tap cancels", composer.compose(ScreenModel.ConfirmEnd)!!.text)
    }
}
