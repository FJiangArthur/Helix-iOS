// JSON-file backed session archive. Port of NativeSessionsView's data source.
package com.artjiang.helix.data

import android.content.Context
import com.artjiang.helix.core.SessionSummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/**
 * On-disk mirror of [SessionSummary]. The domain type is deliberately not
 * `@Serializable` (core/Domain.kt is shared and owned elsewhere), so the
 * persistence shape lives here and converts at the boundary.
 */
@Serializable
private data class StoredSession(
    val id: String,
    val title: String,
    val answerPreview: String,
    val transcriptTurns: List<String>,
    val answerCount: Int,
    val createdAtMillis: Long,
) {
    fun toDomain() = SessionSummary(id, title, answerPreview, transcriptTurns, answerCount, createdAtMillis)

    companion object {
        fun from(summary: SessionSummary) = StoredSession(
            summary.id,
            summary.title,
            summary.answerPreview,
            summary.transcriptTurns,
            summary.answerCount,
            summary.createdAtMillis,
        )
    }
}

class SessionRepository(context: Context) {

    private val file = File(context.applicationContext.filesDir, FILE_NAME)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val serializer = ListSerializer(StoredSession.serializer())

    private val sessionsState = MutableStateFlow(load())
    val sessions: StateFlow<List<SessionSummary>> = sessionsState.asStateFlow()

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
        persist(listOf(summary) + sessionsState.value)
    }

    suspend fun remove(id: String) {
        persist(sessionsState.value.filterNot { it.id == id })
    }

    private suspend fun persist(next: List<SessionSummary>) {
        sessionsState.value = next
        withContext(Dispatchers.IO) {
            runCatching { file.writeText(json.encodeToString(serializer, next.map(StoredSession::from))) }
        }
    }

    private fun load(): List<SessionSummary> {
        if (!file.exists()) return emptyList()
        return runCatching {
            json.decodeFromString(serializer, file.readText()).map { it.toDomain() }
        }.getOrDefault(emptyList())
    }

    private companion object {
        const val FILE_NAME = "helix_sessions.json"
    }
}
