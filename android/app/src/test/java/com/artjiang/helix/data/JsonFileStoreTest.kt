package com.artjiang.helix.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.serializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class JsonFileStoreTest {

    @get:Rule
    val tmp = TemporaryFolder()

    @Serializable
    private data class Entry(val id: Int, val text: String)

    private fun <T> withStore(
        file: File,
        serializer: kotlinx.serialization.KSerializer<T>,
        block: suspend (JsonFileStore<T>) -> Unit,
    ) = runBlocking {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            block(JsonFileStore(file, serializer, scope))
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `mutations persist and reload`() {
        val file = File(tmp.root, "store.json")
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it + Entry(1, "one") }
            store.mutate { it + Entry(2, "two") }
            assertEquals(listOf(Entry(1, "one"), Entry(2, "two")), store.items.value)
        }
        // A fresh store over the same file sees the persisted data.
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it } // await load
            assertEquals(2, store.items.value.size)
        }
    }

    @Test
    fun `mutation before load completes cannot clobber existing data`() {
        val file = File(tmp.root, "store.json")
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it + Entry(1, "existing") }
        }
        // Immediately mutate on a brand-new store: mutate() must wait for the
        // initial load, so the existing entry survives.
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it + Entry(2, "new") }
            assertEquals(listOf(Entry(1, "existing"), Entry(2, "new")), store.items.value)
        }
    }

    @Test
    fun `loaded waits for the initial disk read`() {
        val file = File(tmp.root, "store.json")
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it + Entry(1, "saved") }
        }
        // Read immediately on a brand-new store: loaded() must await the async
        // initial load rather than returning the empty pre-load state.
        withStore(file, Entry.serializer()) { store ->
            assertEquals(listOf(Entry(1, "saved")), store.loaded())
        }
    }

    @Test
    fun `corrupt file degrades to empty instead of crashing`() {
        val file = File(tmp.root, "store.json")
        file.writeText("{not json[")
        withStore(file, Entry.serializer()) { store ->
            store.mutate { it + Entry(1, "fresh") }
            assertEquals(1, store.items.value.size)
        }
    }

    @Test
    fun `write leaves no temp file behind`() {
        val file = File(tmp.root, "store.json")
        withStore(file, String.serializer()) { store ->
            store.mutate { it + "hello" }
        }
        assertFalse(File(tmp.root, "store.json.tmp").exists())
        assertEquals(true, file.exists())
    }
}
