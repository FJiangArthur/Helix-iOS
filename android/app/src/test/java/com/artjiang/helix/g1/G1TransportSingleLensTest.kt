// Regression: a screen must still succeed when only ONE lens is connected.
//
// `HelixBridge.isGlassesConnected` is an OR (left READY || right READY) and
// G1BluetoothManager reports "Connected (left lens)" as a supported state, so
// a one-lens link is a first-class configuration — not an error.
//
// Before this fix `sendScreen` ANDed both lenses, so the absent lens's `false`
// failed the whole screen. G1HudSession aborts its lifecycle when the first
// push fails, which meant the 0x41 DISPLAY_COMPLETE was never scheduled: the
// HUD lit up and never blanked, and "Send to glasses" looked like a no-op.
package com.artjiang.helix.g1

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class G1TransportSingleLensTest {

    /** Accepts writes for [live] only, mimicking one disconnected lens. */
    /**
     * Accepts writes for [live] only, mimicking one disconnected lens.
     *
     * Since SLA-L2 the transport ACK-gates every screen packet, so the live
     * lens must acknowledge what it takes — a real lens replies to each 0x4E.
     * The absent lens stays silent, which is the whole point: the transport has
     * to tell "refused, never connected" apart from "took the bytes and then
     * went quiet". [ackStatus] covers both codes the decoder accepts.
     */
    private class OneLensWriter(
        private val live: G1Side,
        private val ackStatus: Byte = G1StatusDecoder.ACK_SUCCESS,
    ) : G1PacketWriter {
        lateinit var transport: G1CommandTransport
        val written = mutableListOf<G1SentPacket>()

        override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
            if (side != live) return false
            written.add(G1SentPacket(bytes, side))
            // RAW bytes through handleInbound so G1StatusDecoder stays in the
            // loop: 0x4E was once missing from its ACK command list, which made
            // real frames decode to null and would have timed out every screen
            // on hardware while decoded-event fakes kept passing.
            transport.handleInbound(byteArrayOf(bytes[0], ackStatus), side)
            return true
        }
    }

    private fun transportFor(writer: OneLensWriter): G1CommandTransport =
        G1CommandTransport(writer).also { writer.transport = it }

    private fun screen(): List<ByteArray> =
        listOf(byteArrayOf(0x4E, 1, 0, 0, 0x31), byteArrayOf(0x4E, 1, 0, 1, 0x31))

    @Test
    fun screenSucceedsWhenOnlyTheLeftLensIsConnected() = runTest {
        val writer = OneLensWriter(G1Side.LEFT)
        val transport = transportFor(writer)
        val outcome = transport.sendScreenDetailed(screen())

        assertTrue(
            "a left-only link must still count as a delivered screen",
            outcome.isSuccessful,
        )
        assertEquals(G1ScreenDeliveryCoverage.LEFT_ONLY, outcome.coverage)
        assertEquals(G1LensDeliveryStatus.DELIVERED, outcome.left)
        assertEquals(G1LensDeliveryStatus.ABSENT, outcome.right)
        assertEquals(2, writer.written.size)
    }

    @Test
    fun screenSucceedsWhenOnlyTheRightLensIsConnected() = runTest {
        val writer = OneLensWriter(G1Side.RIGHT)
        val transport = transportFor(writer)
        val outcome = transport.sendScreenDetailed(screen())

        assertTrue(outcome.isSuccessful)
        assertEquals(G1ScreenDeliveryCoverage.RIGHT_ONLY, outcome.coverage)
        assertEquals(G1LensDeliveryStatus.ABSENT, outcome.left)
        assertEquals(G1LensDeliveryStatus.DELIVERED, outcome.right)
        assertEquals(2, writer.written.size)
    }

    /**
     * The specific regression SLA-L1 could reintroduce.
     *
     * The vendor aborts the screen whenever the left list fails
     * (`proto.dart:55-71`) — but it assumes both lenses are present and ACKing.
     * Applying that rule literally would make an ABSENT left lens abort before
     * the right one is ever written, resurrecting the exact dated bug this
     * file's header describes: G1HudSession aborts on the failed push, the
     * DISPLAY_COMPLETE that blanks the HUD is never scheduled, the display
     * stays lit forever, and "Send to glasses" looks like a no-op.
     *
     * So a left lens that was never connected must NOT suppress the right one.
     */
    @Test
    fun anAbsentLeftLensMustNotAbortTheScreenBeforeTheRightIsWritten() = runTest {
        val writer = OneLensWriter(G1Side.RIGHT)
        val transport = transportFor(writer)

        assertTrue(
            "SLA-L1's left-abort must not fire for a lens that is merely absent",
            transport.sendScreen(screen()),
        )
        assertEquals(
            "the right lens must still receive every packet",
            2,
            writer.written.count { it.side == G1Side.RIGHT },
        )
    }

    /**
     * The other half of the distinction: a lens that ACCEPTED the bytes and
     * then went silent is holding a half-drawn page. That is a genuine
     * in-flight failure, so SLA-L1 applies and the right lens is never written.
     */
    @Test
    fun aConnectedButUnresponsiveLeftLensDoesAbortTheScreen() = runTest {
        val writer = object : G1PacketWriter {
            val written = mutableListOf<G1SentPacket>()
            override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
                written.add(G1SentPacket(bytes, side))
                return true // taken by the stack, but never acknowledged
            }
        }
        val transport = G1CommandTransport(writer)
        val outcome = transport.sendScreenDetailed(screen())

        assertFalse(
            "a present lens that never ACKs is a real failure, not an absent lens",
            outcome.isSuccessful,
        )
        assertEquals(G1LensDeliveryStatus.FAILED, outcome.left)
        assertEquals(G1LensDeliveryStatus.NOT_ATTEMPTED, outcome.right)
        assertTrue(
            "SLA-L1: right must never be written after a genuine left failure",
            writer.written.none { it.side == G1Side.RIGHT },
        )
    }

    @Test
    fun screenStillFailsWhenNeitherLensAccepts() = runTest {
        val writer = object : G1PacketWriter {
            override suspend fun write(bytes: ByteArray, side: G1Side) = false
        }
        val outcome = G1CommandTransport(writer).sendScreenDetailed(screen())
        assertFalse(
            "with no lens reachable the screen genuinely failed",
            outcome.isSuccessful,
        )
        assertEquals(G1LensDeliveryStatus.ABSENT, outcome.left)
        assertEquals(G1LensDeliveryStatus.ABSENT, outcome.right)
    }

    @Test
    fun bothLensesConnectedStillReportsSuccess() = runTest {
        lateinit var transport: G1CommandTransport
        val writer = object : G1PacketWriter {
            val written = mutableListOf<G1SentPacket>()
            override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
                written.add(G1SentPacket(bytes, side))
                transport.handleInbound(
                    byteArrayOf(bytes[0], G1StatusDecoder.ACK_SUCCESS),
                    side,
                )
                return true
            }
        }
        transport = G1CommandTransport(writer)

        val outcome = transport.sendScreenDetailed(screen())
        assertTrue(outcome.isSuccessful)
        assertEquals(G1ScreenDeliveryCoverage.BOTH, outcome.coverage)
        assertEquals("both lenses receive every packet", 4, writer.written.size)
    }

    /** SLA-L2: 0xCB is an accepted ACK code, not a failure like 0xCA. */
    @Test
    fun singleLensLinkAlsoAcceptsThe0xCBAckCode() = runTest {
        val writer = OneLensWriter(G1Side.LEFT, ackStatus = G1StatusDecoder.ACK_CONTINUE)
        val transport = transportFor(writer)

        assertTrue(transport.sendScreen(screen()))
        assertEquals(2, writer.written.size)
    }
}
