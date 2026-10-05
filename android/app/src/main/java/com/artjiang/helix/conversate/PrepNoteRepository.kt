// Prep Notes: wearer-supplied context loaded into a Conversate session.
package com.artjiang.helix.conversate

import com.artjiang.helix.data.JsonFileStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import java.io.File
import java.util.UUID

@Serializable
data class PrepNote(val id: String, val title: String, val text: String, val updatedAtMillis: Long) {
    fun toRef() = PrepNoteRef(id, title, text)
}

class PrepNoteRepository(file: File, scope: CoroutineScope) {
    companion object {
        const val MAX_CHARS = 5_000
        fun new(title: String, text: String, now: Long) =
            PrepNote(UUID.randomUUID().toString(), title.trim().ifEmpty { "Untitled" }, text.take(MAX_CHARS), now)
    }

    private val store = JsonFileStore(file, PrepNote.serializer(), scope)
    val notes: StateFlow<List<PrepNote>> = store.items

    suspend fun upsert(note: PrepNote) = store.mutate { list ->
        val capped = note.copy(text = note.text.take(MAX_CHARS))
        if (list.any { it.id == capped.id }) list.map { if (it.id == capped.id) capped else it } else list + capped
    }

    suspend fun delete(id: String) = store.mutate { list -> list.filterNot { it.id == id } }

    suspend fun loaded(): List<PrepNote> = store.loaded()
}
