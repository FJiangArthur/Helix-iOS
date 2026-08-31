package com.artjiang.helix.g1

import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for discarded write results: a rejected write used to be
 * reported as success (garbling multi-packet pages with no error), and an
 * ACK-required command to a dead lens burned the full 5s x 3 ACK budget for
 * bytes that never left the phone.
 */
class G1TransportWriteResultTest {

    private class FailingWriter(
        private val failFor: Set<G1Side> = emptySet(),
    ) : G1PacketWriter {
        var attempts = 0
            private set

        override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
            attempts += 1
            return side !in failFor
        }
    }

    @Test
    fun `ack-less send reports a rejected write as failure`() = runTest {
        val transport = G1CommandTransport(FailingWriter(failFor = setOf(G1Side.LEFT)))

        val ok = transport.send(
            G1Command(bytes = byteArrayOf(0x25), postDelayMillis = 0),
        )

        assertFalse("a dropped packet must not report success", ok)
    }

    @Test
    fun `ack-less send succeeds when both sides accept`() = runTest {
        val transport = G1CommandTransport(FailingWriter())

        val ok = transport.send(
            G1Command(bytes = byteArrayOf(0x25), postDelayMillis = 0),
        )

        assertTrue(ok)
    }

    @Test
    fun `ack-required command fails fast when the write is rejected`() = runTest {
        val transport = G1CommandTransport(FailingWriter(failFor = setOf(G1Side.LEFT, G1Side.RIGHT)))

        val started = currentTime
        val ok = transport.send(
            G1Command(
                bytes = byteArrayOf(0x4D, 0xFB.toByte()),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            ),
        )
        val elapsed = currentTime - started

        assertFalse(ok)
        // Retries still happen (3 attempts x backoff), but no attempt waits
        // out the 5s ACK timeout for bytes that never left the phone.
        assertTrue(
            "expected only retry backoff (<1s), got ${elapsed}ms",
            elapsed < G1CommandTransport.DEFAULT_ACK_TIMEOUT_MILLIS,
        )
    }

    @Test
    fun `sent log is bounded`() = runTest {
        val transport = G1CommandTransport(FailingWriter())

        repeat(G1CommandTransport.SENT_LOG_CAPACITY + 50) { index ->
            transport.send(
                G1Command(
                    bytes = byteArrayOf(0x25, index.toByte()),
                    sides = listOf(G1Side.LEFT),
                    postDelayMillis = 0,
                ),
            )
        }

        assertEquals(G1CommandTransport.SENT_LOG_CAPACITY, transport.sentLog.size)
    }
}
