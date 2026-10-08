package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MenuSpecTest {
    @Test
    fun `menu loads from conversate-core`() {
        val spec = MenuSpec.load()
        assertEquals(listOf("start", "ask", "news", "x", "todos", "omi", "mode", "display"), spec.idle.map { it.id })
        assertEquals(
            listOf("pause", "captions", "cues", "prep_note", "ask", "news", "x", "todos", "omi", "mode", "display", "display_off", "end"),
            spec.live.map { it.id },
        )
    }

    @Test
    fun `pickers and panels parse from menu v2`() {
        val spec = MenuSpec.load()
        assertEquals(2, spec.version)
        assertEquals("MODE", spec.pickers.getValue("mode").title)
        assertEquals(listOf("PHONE_MIC", "OMI", "DISPLAY_ONLY"), spec.pickers.getValue("mode").items.map { it.id })
        val display = spec.pickers.getValue("display")
        assertEquals(listOf("2", "3", "4", "5"), display.items.first { it.id == "captionLines" }.valueStrings)
        assertEquals("Captions: on", display.items.first { it.id == "captions" }.renderValue("on"))
        assertEquals("TO-DO", spec.panels.getValue("todos").title)
        assertEquals(setOf("news", "x", "todos", "omi"), spec.panels.keys)
    }

    @Test
    fun `toggle items render from flags`() {
        val pause = MenuSpec.load().live.first { it.id == "pause" }
        assertEquals("Pause", pause.render(mapOf("paused" to false)))
        assertEquals("Resume", pause.render(mapOf("paused" to true)))
    }

    @Test
    fun `cue prompt fills placeholders`() {
        val prompt = CuePrompt.load()
        assertEquals(600, prompt.maxTokens)
        val text = prompt.render(transcript = "We use RAG.", prepNote = "", shown = listOf("RAG"))
        assertTrue(text.contains("We use RAG."))
        assertTrue(text.contains("cues: RAG"))
        assertTrue(!text.contains("{{"))
    }

    @Test
    fun `every menu label fits 32 bytes for the G2 native menu`() {
        val spec = MenuSpec.load()
        (spec.idle + spec.live).flatMap { listOfNotNull(it.label, it.labelOn, it.labelOff) }
            .forEach { assertTrue(it, it.toByteArray().size <= 32) }
    }
}
