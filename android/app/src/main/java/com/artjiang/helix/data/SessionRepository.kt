// JSON-file backed session archive. Port of NativeSessionsView's data source.
package com.artjiang.helix.data

import android.content.Context
import com.artjiang.helix.core.SessionSummary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.UUID

class SessionRepository(context: Context, scope: CoroutineScope) {

    private val store = JsonFileStore(
        file = File(context.applicationContext.filesDir, FILE_NAME),
        serializer = SessionSummary.serializer(),
        scope = scope,
    )

    val sessions: StateFlow<List<SessionSummary>> = store.items

    suspend fun add(
        title: String,
        answerPreview: String,
        transcriptTurns: List<String>,
        answerCount: Int,
    ) {
        val summary = SessionSummary(
            id = UUID.randomUUID().toString(),
            title = title.ifBlank { "Helix session" },
            answerPreview = answerPreview,
            transcriptTurns = transcriptTurns,
            answerCount = answerCount,
            createdAtMillis = System.currentTimeMillis(),
        )
        // Newest first — the archive list reads top-down like the iOS view.
        store.mutate { current -> listOf(summary) + current }
    }

    suspend fun remove(id: String) {
        store.mutate { current -> current.filterNot { it.id == id } }
    }

    /**
     * Bulk insert for imports: adds only summaries whose id is not already
     * stored (imported records carry stable remote-derived ids, so a re-import
     * is a no-op) in a single file rewrite. Returns the number added.
     */
    suspend fun addAllIfAbsent(summaries: List<SessionSummary>): Int {
        var added = 0
        store.mutate { current ->
            val existing = current.mapTo(HashSet()) { it.id }
            val fresh = summaries.filter { existing.add(it.id) }
            added = fresh.size
            if (fresh.isEmpty()) current
            else (fresh + current).sortedByDescending { it.createdAtMillis }
        }
        return added
    }

    private companion object {
        const val FILE_NAME = "helix_sessions.json"
    }
}
