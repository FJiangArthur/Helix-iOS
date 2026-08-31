package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SLA-L2: the vendor accepts BOTH 0xC9 and 0xCB as a successful ACK; only 0xCA
 * (and anything else) is a failure.
 *
 *   `resp.data[1] != 0xc9 && resp.data[1] != 0xcB` -> failure
 *   EvenDemoApp @3899aac, lib/ble_manager.dart:396
 *
 * Helix has always accepted 0xCB (G1StatusDecoder.ACK_CONTINUE); these tests
 * pin that so a future "simplification" to a single success code is caught.
 */
class G1StatusDecoderAckTest {

    /** Every command byte routed through the shared ACK branch of `decode`. */
    private val ackCommands = listOf<Byte>(
        0x4D, 0x26, 0x0B, 0x01, 0x0E, 0x04, 0x03, 0x27,
    )

    @Test
    fun `0xC9 is a successful ack for every ack-bearing command`() {
        for (command in ackCommands) {
            val event = G1StatusDecoder.decode(byteArrayOf(command, 0xC9.toByte()))
            assertEquals(G1StatusEvent.Ack(command = command, success = true), event)
        }
    }

    @Test
    fun `0xCB is also a successful ack - vendor accepts C9 and CB alike`() {
        for (command in ackCommands) {
            val event = G1StatusDecoder.decode(byteArrayOf(command, 0xCB.toByte()))
            assertEquals(
                "0xCB must be success for command 0x${command.toString(16)}",
                G1StatusEvent.Ack(command = command, success = true),
                event,
            )
        }
    }

    @Test
    fun `0xCA is a failure ack`() {
        for (command in ackCommands) {
            val event = G1StatusDecoder.decode(byteArrayOf(command, 0xCA.toByte()))
            assertEquals(G1StatusEvent.Ack(command = command, success = false), event)
        }
    }

    @Test
    fun `ack constants match the vendor wire values`() {
        assertEquals(0xC9, G1StatusDecoder.ACK_SUCCESS.toInt() and 0xFF)
        assertEquals(0xCB, G1StatusDecoder.ACK_CONTINUE.toInt() and 0xFF)
    }

    @Test
    fun `datetime reply keeps its own success codes alongside C9 and CB`() {
        for (status in listOf<Byte>(0x07, 0x90.toByte(), 0x0C, 0xC9.toByte(), 0xCB.toByte())) {
            val event = G1StatusDecoder.decode(byteArrayOf(0x06, status))
            assertTrue(
                "0x06 status 0x${status.toString(16)} should be success",
                (event as G1StatusEvent.Ack).success,
            )
        }
        val failure = G1StatusDecoder.decode(byteArrayOf(0x06, 0xCA.toByte()))
        assertEquals(G1StatusEvent.Ack(command = 0x06, success = false), failure)
    }

    @Test
    fun `a one-byte ack frame decodes to null rather than a false failure`() {
        assertEquals(null, G1StatusDecoder.decode(byteArrayOf(0x4D)))
    }
}
