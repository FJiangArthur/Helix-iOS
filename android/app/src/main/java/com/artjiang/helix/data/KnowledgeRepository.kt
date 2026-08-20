// JSON-file backed knowledge store. Port of the knowledge library half of the
// iOS runtime (NativeKnowledgeView's data source).
package com.artjiang.helix.data

import android.content.Context
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/**
 * Knowledge items (projects / facts / memories / todos) persisted as one JSON
 * array in filesDir. Small, bounded data — a whole-file rewrite per mutation is
 * simpler and safer here than a database, and keeps the port dependency-free.
 */
class KnowledgeRepository(context: Context) {

    private val file = File(context.applicationContext.filesDir, FILE_NAME)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val serializer = ListSerializer(KnowledgeItem.serializer())

    private val itemsState = MutableStateFlow(load())
    val items: StateFlow<List<KnowledgeItem>> = itemsState.asStateFlow()

    fun itemsIn(bucket: KnowledgeBucket): List<KnowledgeItem> =
        itemsState.value.filter { it.bucket == bucket.name }

    suspend fun add(bucket: KnowledgeBucket, text: String, source: String = "Manual") {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val item = KnowledgeItem(
            id = UUID.randomUUID().toString(),
            bucket = bucket.name,
            text = trimmed,
            source = source,
            createdAtMillis = System.currentTimeMillis(),
        )
        persist(itemsState.value + item)
    }

    suspend fun remove(id: String) {
        persist(itemsState.value.filterNot { it.id == id })
    }

    /** Simple keyword retrieval used as the engine's knowledge provider. */
    fun search(query: String, limit: Int = 3): List<String> {
        val terms = query.lowercase().split(Regex("\\W+")).filter { it.length > 3 }
        if (terms.isEmpty()) return emptyList()
        return itemsState.value
            .filter { item -> terms.any { item.text.lowercase().contains(it) } }
            .sortedByDescending { it.createdAtMillis }
            .take(limit)
            .map { it.text }
    }

    private suspend fun persist(next: List<KnowledgeItem>) {
        itemsState.value = next
        withContext(Dispatchers.IO) {
            runCatching { file.writeText(json.encodeToString(serializer, next)) }
        }
    }

    private fun load(): List<KnowledgeItem> {
        if (!file.exists()) return emptyList()
        return runCatching { json.decodeFromString(serializer, file.readText()) }.getOrDefault(emptyList())
    }

    private companion object {
        const val FILE_NAME = "helix_knowledge.json"
    }
}
