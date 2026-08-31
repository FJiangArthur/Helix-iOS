package com.artjiang.helix

import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import org.junit.Assert.assertEquals
import org.junit.Test

class AutomaticNoteReceiptTest {

    @Test
    fun `rapid multi-answer saves merge into one undoable receipt`() {
        val first = AutomaticNoteReceipt(
            listOf(AutomaticNoteSavedItem("one", KnowledgeBucket.FACTS, "Q: One?\nA: First.")),
        )
        val merged = first.mergedWith(
            listOf(
                AutomaticNoteSavedItem("two", KnowledgeBucket.FACTS, "Q: Two?\nA: Second."),
                AutomaticNoteSavedItem("one", KnowledgeBucket.FACTS, "duplicate callback"),
            ),
        )

        assertEquals(listOf("one", "two"), merged.itemIds)
        assertEquals("Saved 2 notes automatically to Helix Knowledge", merged.message)
    }

    @Test
    fun `same-item updates keep earliest undo state and latest preview`() {
        val original = KnowledgeItem(
            id = "one",
            bucket = KnowledgeBucket.FACTS,
            text = "Q: One?\nA: Fast.",
            source = "Helix auto-note · Answer · FAST",
            createdAtMillis = 1,
        )
        val first = AutomaticNoteReceipt(
            listOf(
                AutomaticNoteSavedItem(
                    "one",
                    KnowledgeBucket.FACTS,
                    "Q: One?\nA: Smart.",
                    previousItem = original,
                ),
            ),
        )
        val merged = first.mergedWith(
            listOf(
                AutomaticNoteSavedItem(
                    "one",
                    KnowledgeBucket.FACTS,
                    "Q: One?\nA: Corrected smart answer.",
                    previousItem = original.copy(text = "intermediate"),
                ),
            ),
        )

        assertEquals(1, merged.items.size)
        assertEquals(original, merged.items.single().previousItem)
        assertEquals("Q: One?\nA: Corrected smart answer.", merged.preview)
        assertEquals("Updated automatically in Helix Knowledge · Facts", merged.message)
    }
}
