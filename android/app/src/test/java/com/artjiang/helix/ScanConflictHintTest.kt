package com.artjiang.helix

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SLA-T1 (advertising exclusivity). A connected BLE peripheral stops
 * advertising, so while the official Even Realities app (`com.even.g1`) holds
 * GATT links to both lenses, Helix's name-based scan can never see them.
 *
 * Android exposes no reliable way to observe another app's GATT connections,
 * so the detection is a heuristic — these tests pin exactly when it fires and,
 * just as importantly, when it stays quiet.
 */
class ScanConflictHintTest {

    private fun hint(
        foundPairs: Int = 0,
        isScanning: Boolean = true,
        vendorAppInstalled: Boolean = true,
    ) = HelixBridge.scanConflictHint(foundPairs, isScanning, vendorAppInstalled)

    @Test
    fun `fires when a live scan finds nothing and the vendor app is installed`() {
        val message = hint()
        assertNotNull(message)
        assertTrue(message!!.contains("Even Realities"))
        assertTrue("must tell the user what to do", message.contains("Force-close"))
    }

    @Test
    fun `stays quiet when the vendor app is not installed`() {
        assertNull(hint(vendorAppInstalled = false))
    }

    @Test
    fun `stays quiet once any pair has been discovered`() {
        assertNull(hint(foundPairs = 1))
        assertNull(hint(foundPairs = 3))
    }

    @Test
    fun `stays quiet when the scan already stopped`() {
        assertNull(hint(isScanning = false))
    }

    @Test
    fun `is worded as a possibility, not a diagnosis`() {
        val message = hint()!!
        assertTrue(
            "heuristic must hedge — we cannot observe another app's GATT links",
            message.contains("may be"),
        )
    }

    @Test
    fun `vendor package id matches the official app`() {
        // Observed on hardware 2026-08-28.
        org.junit.Assert.assertEquals("com.even.g1", HelixBridge.EVEN_REALITIES_PACKAGE)
    }

    @Test
    fun `timeout is long enough not to misdiagnose a slow pair`() {
        assertTrue(HelixBridge.SCAN_CONFLICT_TIMEOUT_MILLIS >= 10_000L)
    }
}
