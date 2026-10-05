package com.artjiang.helix.conversate

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PrepNoteRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun `upsert, persist, reload, delete`() = runTest {
        val file = tmp.newFile("prep.json").also { it.delete() }
        val repo = PrepNoteRepository(file, backgroundScope)
        val note = PrepNoteRepository.new("Acme", "Context", now = 1)
        repo.upsert(note)
        repo.upsert(note.copy(text = "Updated"))
        assertEquals(listOf("Updated"), repo.loaded().map { it.text })
        val reopened = PrepNoteRepository(file, backgroundScope)
        assertEquals(listOf("Acme"), reopened.loaded().map { it.title })
        reopened.delete(note.id)
        assertEquals(emptyList<PrepNote>(), reopened.loaded())
    }

    @Test
    fun `text is capped at 5000 chars`() {
        val note = PrepNoteRepository.new("t", "x".repeat(6_000), now = 0)
        assertEquals(5_000, note.text.length)
    }
}
