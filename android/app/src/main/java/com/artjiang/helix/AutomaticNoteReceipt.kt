package com.artjiang.helix

import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem

/** One persisted internal-Knowledge item shown in an automatic-save receipt. */
data class AutomaticNoteSavedItem(
    val id: String,
    val bucket: KnowledgeBucket,
    val text: String,
    /** Null means Undo removes a new item; non-null restores an updated item. */
    val previousItem: KnowledgeItem? = null,
)

/**
 * Observable result of one finalized transcript's conservative auto-capture.
 * The wording is deliberately explicit that this is Helix's internal
 * Knowledge store, never Apple Notes or another external notes application.
 */
data class AutomaticNoteReceipt(val items: List<AutomaticNoteSavedItem>) {
    /** Extends the active Undo window without making earlier writes unreachable. */
    fun mergedWith(newItems: List<AutomaticNoteSavedItem>): AutomaticNoteReceipt {
        val merged = LinkedHashMap<String, AutomaticNoteSavedItem>()
        items.forEach { merged[it.id] = it }
        newItems.forEach { incoming ->
            val earliest = merged[incoming.id]
            merged[incoming.id] = if (earliest == null) {
                incoming
            } else {
                incoming.copy(previousItem = earliest.previousItem)
            }
        }
        return AutomaticNoteReceipt(merged.values.toList())
    }

    val message: String
        get() = if (items.size == 1) {
            val item = items.single()
            if (item.previousItem == null) {
                "Saved automatically to Helix Knowledge · ${bucketTitle(item.bucket)}"
            } else {
                "Updated automatically in Helix Knowledge · ${bucketTitle(item.bucket)}"
            }
        } else if (items.all { it.previousItem == null }) {
            "Saved ${items.size} notes automatically to Helix Knowledge"
        } else {
            "Saved or updated ${items.size} notes automatically in Helix Knowledge"
        }

    val preview: String
        get() = items.firstOrNull()?.text.orEmpty()

    val itemIds: List<String>
        get() = items.map { it.id }

    private fun bucketTitle(bucket: KnowledgeBucket): String = when (bucket) {
        KnowledgeBucket.PROJECTS -> "Projects"
        KnowledgeBucket.FACTS -> "Facts"
        KnowledgeBucket.MEMORIES -> "Memories"
        KnowledgeBucket.TODOS -> "Todos"
    }
}
