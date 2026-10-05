package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MenuSpecTest {
    @Test
    fun `menu loads from conversate-core`() {
        val spec = MenuSpec.load()
        assertEquals(listOf("start"), spec.idle.map { it.id })
        assertEquals(listOf("pause", "captions", "cues", "prep_note", "display_off", "end"), spec.live.map { it.id })
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
