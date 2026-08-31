// JSON-file backed conversation feed. The Assistant tab's feed used to live
// only in a MutableStateFlow inside HelixBridge, so every process death threw
// the whole conversation away ("conversations are not saving in the chat",
// "cannot resume a conversation after restarting"). Same JsonFileStore shape
// as SessionRepository / KnowledgeRepository.
package com.artjiang.helix.data

import android.content.Context
import com.artjiang.helix.FeedEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/**
 * The Assistant conversation feed, persisted as one JSON array in filesDir.
 *
 * Bounded to [limit] entries on every write, so the file can never grow
 * without end — the cap that [com.artjiang.helix.HelixBridge] used to apply
 * only in memory now also governs what reaches disk.
 *
 * All writes go through [JsonFileStore.mutate], which suspends on the bridge
 * scope and does the actual file I/O on [kotlinx.coroutines.Dispatchers.IO],
 * so appending never blocks the UI thread.
 */
class FeedRepository internal constructor(
    file: File,
    scope: CoroutineScope,
    private val limit: Int = DEFAULT_LIMIT,
) {

    /**
     * Production entry point. The [File] constructor above is what the unit
     * tests use: this module has no Robolectric, so anything that touches a
     * real [Context] cannot be exercised on the JVM (the same reason
     * JsonFileStore is tested directly rather than through a repository).
     */
    constructor(
        context: Context,
        scope: CoroutineScope,
        limit: Int = DEFAULT_LIMIT,
    ) : this(File(context.applicationContext.filesDir, FILE_NAME), scope, limit)

    private val store = JsonFileStore(
        file = file,
        serializer = FeedEntry.serializer(),
        scope = scope,
    )

    /** Oldest first, newest last — the order the Assistant list renders. */
    val entries: StateFlow<List<FeedEntry>> = store.items

    /** Appends [entry] and trims to the newest [limit] rows. */
    suspend fun append(entry: FeedEntry) {
        store.mutate { current -> (current + entry).takeLast(limit) }
    }

    /**
     * Promotes the exact finalized transcript that produced a detected
     * question instead of appending the same words as a second feed row.
     * Copying only [FeedEntry.kind] preserves id, speaker, side attribution,
     * timestamp, and text. A question that is merely a substring of a larger
     * transcript block is intentionally not merged.
     */
    suspend fun promoteMatchingTranscriptToQuestion(
        transcriptEntryId: Long,
        questionText: String,
    ): Boolean {
        val expected = comparableText(questionText)
        if (expected.isEmpty()) return false
        var promoted = false
        store.mutate { current ->
            val index = current.indexOfFirst { entry ->
                entry.id == transcriptEntryId &&
                    entry.kind == FeedEntry.Kind.TRANSCRIPT &&
                    comparableText(entry.text) == expected
            }
            if (index < 0) {
                current
            } else {
                promoted = true
                current.toMutableList().also { rows ->
                    rows[index] = rows[index].copy(kind = FeedEntry.Kind.QUESTION)
                }
            }
        }
        return promoted
    }

    /**
     * The stored list, guaranteed past the initial disk load.
     *
     * The bridge needs this to resume its id counter: ids are a monotonic
     * per-process counter, and restarting it at 0 over a restored feed would
     * hand new entries ids that already exist (Compose keys them by id).
     */
    suspend fun loaded(): List<FeedEntry> = store.loaded()

    /** Starts a fresh conversation; the archive keeps saved sessions. */
    suspend fun clear() {
        store.mutate { emptyList() }
    }

    companion object {
        const val FILE_NAME = "helix_feed.json"

        /** Mirrors the in-memory cap the bridge applied before persistence. */
        const val DEFAULT_LIMIT = 200

        private fun comparableText(text: String): String =
            text.trim().replace(Regex("\\s+"), " ")
    }
}
