// Shared JSON-list file persistence for the data layer. KnowledgeRepository
// and SessionRepository previously re-implemented this skeleton line for line
// (each with its own Json instance, non-atomic writeText, and a blocking load
// in the constructor); one store keeps the fix-in-one-place guarantees.
package com.artjiang.helix.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/** One Json configuration for every data-layer store. */
internal val helixDataJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

/**
 * A list of [T] persisted as one JSON array in a file.
 *
 * - The initial load runs on [Dispatchers.IO], not in the constructor —
 *   repositories are built during first-frame setup and the read scales with
 *   stored data.
 * - Writes go to a temp file and rename over the target, so a crash mid-write
 *   cannot corrupt the store.
 * - [mutate] suspends until the initial load completes, so an early mutation
 *   can never base itself on (and then persist) an empty list.
 */
internal class JsonFileStore<T>(
    private val file: File,
    serializer: KSerializer<T>,
    scope: CoroutineScope,
) {
    private val listSerializer = ListSerializer(serializer)

    private val state = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = state.asStateFlow()

    private val ioMutex = Mutex()
    private val initialLoad = CompletableDeferred<Unit>()

    init {
        scope.launch(Dispatchers.IO) {
            ioMutex.withLock {
                state.value = read()
                initialLoad.complete(Unit)
            }
        }
    }

    /** Applies [transform] to the loaded list, publishes it, and persists. */
    suspend fun mutate(transform: (List<T>) -> List<T>) {
        initialLoad.await()
        ioMutex.withLock {
            val next = transform(state.value)
            state.value = next
            withContext(Dispatchers.IO) { write(next) }
        }
    }

    /** The list, guaranteed past the initial load (unlike a raw [items] read). */
    suspend fun loaded(): List<T> {
        initialLoad.await()
        return state.value
    }

    private fun read(): List<T> {
        if (!file.exists()) return emptyList()
        return runCatching { helixDataJson.decodeFromString(listSerializer, file.readText()) }
            .getOrDefault(emptyList())
    }

    private fun write(items: List<T>) {
        runCatching {
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(helixDataJson.encodeToString(listSerializer, items))
            if (!tmp.renameTo(file)) {
                // Some filesystems refuse to rename over an existing file.
                // Never delete the old data before the replacement is confirmed
                // in place: move it aside and restore it if the swap fails, so
                // a failed write can only lose the newest snapshot (still held
                // in memory and re-persisted by the next successful mutate),
                // never the whole store.
                val backup = File(file.parentFile, "${file.name}.bak")
                backup.delete()
                file.renameTo(backup)
                if (tmp.renameTo(file)) {
                    backup.delete()
                } else {
                    backup.renameTo(file)
                }
            }
        }
    }
}
