// SLA-L1 / SLA-L2 conformance for `G1CommandTransport.sendScreen`.
//
// Normative source: docs/G1_PROTOCOL_SLA.md, derived from EvenDemoApp @3899aac.
//  - SLA-L2 (ble_manager.dart:391-399): every 0x4E text packet is individually
//    ACK-gated. Accepted status bytes are 0xC9 and 0xCB; 0xCA is failure.
//  - SLA-L1 (proto.dart:55-71): the left lens must fully succeed before the
//    first right packet is written; on left failure the right is never sent.
//
// Before this fix screen packets used G1AckPolicy.None, so a lens that silently
// dropped half a page was indistinguishable from a clean write.
package com.artjiang.helix.g1

import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class G1TransportScreenAckTest {

    /**
     * Writer that echoes an ACK frame back into the transport for the packets
     * a test says should be acknowledged, mimicking the glasses' 0x4E reply.
     *
     * [ackStatus] is the raw status byte (0xC9 success, 0xCB continue, 0xCA
     * failure); [acceptWrite] decides whether the BLE stack takes the bytes at
     * all; [ackFor] decides whether a reply ever comes back.
     */
    private class AckingWriter(
        val acceptWrite: (G1Side) -> Boolean = { true },
        val ackFor: (G1Side, Int) -> Boolean = { _, _ -> true },
        val ackStatus: Byte = G1StatusDecoder.ACK_SUCCESS,
    ) : G1PacketWriter {
        lateinit var transport: G1CommandTransport
        val written = mutableListOf<G1SentPacket>()
        private val perSideCount = mutableMapOf<G1Side, Int>()

        override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
            if (!acceptWrite(side)) return false
            val index = perSideCount.getOrDefault(side, 0)
            perSideCount[side] = index + 1
            written.add(G1SentPacket(bytes, side))
            if (ackFor(side, index)) {
                // The transport registers its waiter before calling write(), so
                // replying inline is exactly a BLE callback landing mid-write.
                //
                // RAW BYTES through handleInbound, deliberately: feeding an
                // already-decoded event here would bypass G1StatusDecoder and
                // hide exactly the defect that shipped once — 0x4E was missing
                // from the decoder's ACK command list, so real frames decoded
                // to null and every screen would have timed out on hardware
                // while these tests still passed.
                transport.handleInbound(byteArrayOf(bytes[0], ackStatus), side)
            }
            return true
        }

        fun sides(): List<G1Side> = written.map { it.side }
    }

    private fun transportFor(writer: AckingWriter): G1CommandTransport =
        G1CommandTransport(writer).also { writer.transport = it }

    private fun screen(): List<ByteArray> = listOf(
        byteArrayOf(0x4E, 1, 3, 0, 0x71),
        byteArrayOf(0x4E, 1, 3, 1, 0x71),
        byteArrayOf(0x4E, 1, 3, 2, 0x71),
    )

    // MARK: - SLA-L2: per-packet ACK gating

    @Test
    fun `every screen packet is ack-gated and succeeds when all are acked`() = runTest {
        val writer = AckingWriter()
        val transport = transportFor(writer)

        assertTrue(transport.sendScreen(screen()))

        assertEquals("3 packets to each lens", 6, writer.written.size)
        assertEquals(
            List(3) { G1Side.LEFT } + List(3) { G1Side.RIGHT },
            writer.sides(),
        )
        // No retries: each packet was written exactly once because each ACKed.
        assertEquals(listOf(0, 1, 2, 0, 1, 2), writer.written.map { it.bytes[3].toInt() })
    }

    @Test
    fun `0xCB is accepted as an ack alongside 0xC9`() = runTest {
        // SLA-L2: the vendor accepts 0xC9 AND 0xCB. 0xCB must not be mistaken
        // for the 0xCA failure code.
        val writer = AckingWriter(ackStatus = G1StatusDecoder.ACK_CONTINUE)
        val transport = transportFor(writer)

        assertTrue("0xCB must count as a successful ACK", transport.sendScreen(screen()))
    }

    @Test
    fun `an ack timeout aborts the screen`() = runTest {
        // The lens takes the bytes but never replies to packet index 1.
        val writer = AckingWriter(ackFor = { side, index -> !(side == G1Side.LEFT && index >= 1) })
        val transport = transportFor(writer)

        assertFalse(
            "an unacknowledged packet must fail the screen, not silently pass",
            transport.sendScreen(screen()),
        )
    }

    @Test
    fun `an unacked packet is retried before the screen is abandoned`() = runTest {
        val writer = AckingWriter(ackFor = { _, index -> index == 0 })
        val transport = transportFor(writer)

        transport.sendScreen(screen())

        val left = writer.written.filter { it.side == G1Side.LEFT }
        // Packet 0 acked once; packet 1 burned the full retry budget.
        assertEquals(1 + G1CommandTransport.MAX_ATTEMPTS, left.size)
        assertTrue(left.drop(1).all { it.bytes[3].toInt() == 1 })
    }

    // MARK: - SLA-L1: left fully succeeds before right begins

    @Test
    fun `left ack failure means the right lens is never written`() = runTest {
        // Left is connected (writes accepted) but stops acknowledging mid-page.
        val writer = AckingWriter(ackFor = { side, index -> side != G1Side.LEFT || index == 0 })
        val transport = transportFor(writer)

        assertFalse(transport.sendScreen(screen()))

        assertTrue(
            "SLA-L1: right must never be written after a left failure, got ${writer.sides()}",
            writer.written.none { it.side == G1Side.RIGHT },
        )
    }

    @Test
    fun `left failure aborts at the failing packet rather than pushing the rest`() = runTest {
        val writer = AckingWriter(ackFor = { _, index -> index == 0 })
        val transport = transportFor(writer)

        transport.sendScreen(screen())

        assertTrue(
            "packet 2 must never go out after packet 1 failed",
            writer.written.none { it.bytes[3].toInt() == 2 },
        )
    }

    @Test
    fun `right lens is written only after every left packet has acked`() = runTest {
        val writer = AckingWriter()
        val transport = transportFor(writer)

        transport.sendScreen(screen())

        val firstRight = writer.sides().indexOf(G1Side.RIGHT)
        assertEquals("all 3 left packets precede the first right packet", 3, firstRight)
    }

    // MARK: - Single-lens reconciliation (Helix divergence from the vendor)

    @Test
    fun `screen still succeeds when only the left lens is connected`() = runTest {
        // The right lens is ABSENT: the stack refuses its very first write.
        val writer = AckingWriter(acceptWrite = { it == G1Side.LEFT })
        val transport = transportFor(writer)

        assertTrue(
            "an absent lens must not fail a screen the present lens took",
            transport.sendScreen(screen()),
        )
        assertEquals(3, writer.written.count { it.side == G1Side.LEFT })
    }

    @Test
    fun `screen still succeeds when only the right lens is connected`() = runTest {
        val writer = AckingWriter(acceptWrite = { it == G1Side.RIGHT })
        val transport = transportFor(writer)

        assertTrue(transport.sendScreen(screen()))
        assertEquals(3, writer.written.count { it.side == G1Side.RIGHT })
    }

    @Test
    fun `an absent left lens does not suppress the right lens`() = runTest {
        // Distinguishes ABSENT from FAILED: a lens with no link at all must not
        // trigger the SLA-L1 abort, or a right-only user would get nothing.
        val writer = AckingWriter(acceptWrite = { it == G1Side.RIGHT })
        val transport = transportFor(writer)

        transport.sendScreen(screen())

        assertTrue(writer.written.any { it.side == G1Side.RIGHT })
    }

    @Test
    fun `screen fails when neither lens accepts a write`() = runTest {
        val writer = AckingWriter(acceptWrite = { false })
        val transport = transportFor(writer)

        assertFalse(transport.sendScreen(screen()))
    }

    @Test
    fun `a right lens that acks nothing fails the screen`() = runTest {
        // Right is present (writes accepted) but silent. Unlike an absent lens
        // this is a genuine failure: it is holding a half-drawn page.
        val writer = AckingWriter(ackFor = { side, _ -> side == G1Side.LEFT })
        val transport = transportFor(writer)

        assertFalse(
            "a present-but-unresponsive lens is a real failure",
            transport.sendScreen(screen()),
        )
    }

    @Test
    fun `an empty screen is not reported as delivered`() = runTest {
        val writer = AckingWriter()
        val transport = transportFor(writer)

        assertFalse(transport.sendScreen(emptyList()))
        assertTrue(writer.written.isEmpty())
    }

    // MARK: - End-to-end ACK decoding

    /**
     * SLA-L2 end-to-end: a RAW `0x4E` ACK frame from the glasses must decode
     * and resolve the transport's waiter.
     *
     * This replaces an earlier placeholder that asserted the decoder did NOT
     * handle 0x4E. `G1StatusDecoder.decode` omitted 0x4E from its ACK command
     * list, so a real reply decoded to null, the waiter never resolved, and
     * every screen would have timed out on hardware (packets x 3 attempts x
     * 2 s) — while tests that inject already-decoded events still passed.
     * 0x4E has been added there; this test drives raw bytes through
     * `handleInbound` so that gap cannot silently reopen.
     */
    @Test
    fun `a raw 0x4E ack frame decodes and completes the screen`() = runTest {
        assertEquals(
            G1StatusEvent.Ack(command = 0x4E.toByte(), success = true),
            G1StatusDecoder.decode(byteArrayOf(0x4E, G1StatusDecoder.ACK_SUCCESS)),
        )
        assertEquals(
            "0xCB must also count as success (ble_manager.dart:396)",
            G1StatusEvent.Ack(command = 0x4E.toByte(), success = true),
            G1StatusDecoder.decode(byteArrayOf(0x4E, G1StatusDecoder.ACK_CONTINUE)),
        )
    }

        /**
     * SLA-L2 corollary — a late ACK must never mark a lost packet delivered.
     *
     * Every packet of a screen carries the SAME command byte (0x4E), so an ACK
     * frame is identified only by side + command. A straggler for a packet that
     * already timed out is therefore byte-identical to the ACK the next attempt
     * is waiting for, and must not satisfy it.
     *
     * This test asserts the OBSERVABLE guarantee — a screen whose packet was
     * never acknowledged in time is reported as failed, no matter what arrives
     * afterwards — rather than any particular internal mechanism.
     *
     * Worth recording how that guarantee is actually upheld, because it is not
     * the generation guard in `handleDecoded`. `ackWaiters` holds at most ONE
     * waiter per side, and both abandonment paths remove it: `awaitAck`'s
     * timeout branch (itself generation-checked) and `registerWaiter`, which
     * evicts any leftover before installing a successor. So a straggler finds
     * either the live waiter or no waiter at all — never a stale one. The
     * generation check in `handleDecoded` is unreachable today and documented
     * as defence in depth for a future pipelined/queued waiter design.
     */
    @Test
    fun `a late ack cannot mark a timed-out screen as delivered`() = runTest {
        val ackTimeout = 50L
        lateinit var transport: G1CommandTransport

        val writer = object : G1PacketWriter {
            var leftWrites = 0
            override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
                if (side == G1Side.LEFT) leftWrites += 1
                return true // taken by the stack, never answered in time
            }
        }
        transport = G1CommandTransport(writer, screenAckTimeoutMillis = ackTimeout)

        // A straggling ACK released only after the first attempt's waiter has
        // already expired and been superseded by a retry.
        val straggler = launch {
            delay(ackTimeout + 10)
            transport.handleInbound(byteArrayOf(0x4E, G1StatusDecoder.ACK_SUCCESS), G1Side.LEFT)
        }

        val delivered = transport.sendScreen(listOf(byteArrayOf(0x4E, 1, 1, 0, 0x71)))
        straggler.join()

        assertFalse(
            "a packet that was never acknowledged in time must fail the screen, " +
                "whatever arrives afterwards",
            delivered,
        )
        assertEquals(
            "every attempt should have timed out and retried",
            G1CommandTransport.MAX_ATTEMPTS,
            writer.leftWrites,
        )
    }

    /**
     * Locks in the cross-file dependency ACK gating rests on.
     *
     * SLA-L2 is only real end-to-end if an inbound `0x4E` frame decodes to
     * [G1StatusEvent.Ack]. `G1StatusDecoder` originally omitted 0x4E from its
     * ACK command list, so a genuine reply from the glasses decoded to null,
     * no waiter ever resolved, and every screen would have timed out on
     * hardware while looking perfectly correct in unit tests that fed
     * `handleDecoded` directly. That has since been fixed; this test fails
     * loudly if 0x4E is ever dropped from the decoder again.
     */
    @Test
    fun `0x4E ack frames decode so screen gating works on real hardware`() {
        assertEquals(
            G1StatusEvent.Ack(command = 0x4E, success = true),
            G1StatusDecoder.decode(byteArrayOf(0x4E, G1StatusDecoder.ACK_SUCCESS)),
        )
        assertEquals(
            "0xCB is an accepted ACK code, not a failure",
            G1StatusEvent.Ack(command = 0x4E, success = true),
            G1StatusDecoder.decode(byteArrayOf(0x4E, G1StatusDecoder.ACK_CONTINUE)),
        )
        assertEquals(
            "0xCA is failure, not success",
            G1StatusEvent.Ack(command = 0x4E, success = false),
            G1StatusDecoder.decode(byteArrayOf(0x4E, 0xCA.toByte())),
        )
    }
}
