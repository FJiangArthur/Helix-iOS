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
    fun `blank clears`() { assertNull(composer.compose(ScreenModel.Blank)) }

    @Test
    fun `confirm end`() {
        assertEquals("End session?\n\nDouble-tap again to end\nAny other tap cancels", composer.compose(ScreenModel.ConfirmEnd)!!.text)
    }
}
