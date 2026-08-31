package com.artjiang.helix.ble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Locks the advertised-name parser to `parseG1PeripheralName` in
 * ios/Runner/BluetoothManager.swift — the two platforms must agree on which
 * channel a lens belongs to or pairing silently splits into two "pairs".
 */
class G1NameParsingTest {

    @Test
    fun `parses the standard Even G1 advert name`() {
        val parsed = G1BluetoothManager.parseG1Name("Even G1_45_L_A1B2")
        assertEquals("45", parsed?.channelNumber)
        assertEquals("L", parsed?.side)
    }

    @Test
    fun `parses the right lens`() {
        val parsed = G1BluetoothManager.parseG1Name("Even G1_45_R_A1B2")
        assertEquals("45", parsed?.channelNumber)
        assertEquals("R", parsed?.side)
    }

    @Test
    fun `prefers a numeric neighbour before the side token`() {
        val parsed = G1BluetoothManager.parseG1Name("G1_12_L_99")
        assertEquals("12", parsed?.channelNumber)
    }

    @Test
    fun `falls back to the numeric neighbour after the side token`() {
        val parsed = G1BluetoothManager.parseG1Name("G1_ABC_L_77")
        assertEquals("77", parsed?.channelNumber)
    }

    @Test
    fun `falls back to a non-numeric neighbour when no digits are present`() {
        val parsed = G1BluetoothManager.parseG1Name("G1_ABC_R_XYZ")
        assertEquals("ABC", parsed?.channelNumber)
        assertEquals("R", parsed?.side)
    }

    @Test
    fun `rejects names with no side token`() {
        assertNull(G1BluetoothManager.parseG1Name("Even G1 45"))
        assertNull(G1BluetoothManager.parseG1Name("SomeOtherDevice_12_X_3"))
    }

    @Test
    fun `both lenses of a pair resolve to the same channel`() {
        val left = G1BluetoothManager.parseG1Name("Even G1_88_L_AAAA")
        val right = G1BluetoothManager.parseG1Name("Even G1_88_R_BBBB")
        assertEquals(left?.channelNumber, right?.channelNumber)
    }
}
