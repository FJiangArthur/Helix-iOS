package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Test

class RelayKeyEditTest {
    private val url = "https://mac.tailnet.ts.net"

    @Test
    fun `empty key field on save keeps the stored key`() {
        assertEquals(RelayKeyEdit.Keep, RelayKeyEdit.resolve(url, typedKey = "  ", removeRequested = false))
    }

    @Test
    fun `typed key replaces the stored key`() {
        assertEquals(RelayKeyEdit.Replace("k-new"), RelayKeyEdit.resolve(url, typedKey = " k-new ", removeRequested = false))
    }

    @Test
    fun `remove key clears it even with text typed`() {
        assertEquals(RelayKeyEdit.Remove, RelayKeyEdit.resolve(url, typedKey = "k", removeRequested = true))
    }

    @Test
    fun `clearing the relay URL also removes the key`() {
        assertEquals(RelayKeyEdit.Remove, RelayKeyEdit.resolve("   ", typedKey = "", removeRequested = false))
    }

    @Test
    fun `stored value is null for remove so the key store deletes it`() {
        assertEquals(null, RelayKeyEdit.Remove.storedValue)
        assertEquals("k", RelayKeyEdit.Replace("k").storedValue)
    }

    @Test
    fun `changing the relay host without a new key drops the stored key`() {
        assertEquals(
            RelayKeyEdit.Remove,
            RelayKeyEdit.resolve("https://other.example", typedKey = "", removeRequested = false, previousUrl = url),
        )
    }

    @Test
    fun `same origin with a trailing slash keeps the stored key`() {
        assertEquals(
            RelayKeyEdit.Keep,
            RelayKeyEdit.resolve("$url/", typedKey = "", removeRequested = false, previousUrl = url),
        )
    }

    @Test
    fun `changing host with a newly typed key stores the new key`() {
        assertEquals(
            RelayKeyEdit.Replace("k2"),
            RelayKeyEdit.resolve("https://other.example", typedKey = "k2", removeRequested = false, previousUrl = url),
        )
    }
}
