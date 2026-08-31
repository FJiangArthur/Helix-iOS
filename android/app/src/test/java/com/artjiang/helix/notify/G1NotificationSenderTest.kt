package com.artjiang.helix.notify

import com.artjiang.helix.g1.G1CommandEncoder
import com.artjiang.helix.g1.G1CommandTransport
import com.artjiang.helix.g1.G1PacketWriter
import com.artjiang.helix.g1.G1Side
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class G1NotificationSenderTest {

    /** Records every write; [failFrom] makes writes fail from that call onward. */
    private class FakeWriter(private val failFrom: Int = Int.MAX_VALUE) : G1PacketWriter {
        val writes = mutableListOf<Pair<ByteArray, G1Side>>()
        override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
            writes.add(bytes to side)
            return writes.size < failFrom
        }
    }

    @Test
    fun notificationGoesToTheLeftLensOnly() = runTest {
        val writer = FakeWriter()
        val sender = G1NotificationSender(G1CommandTransport(writer), nowMillis = { 1_700_000_000_000L })

        assertTrue(
            sender.sendNotification(
                appId = "com.artjiang.helix",
                displayName = "Helix",
                title = "Answer ready",
                subtitle = "",
                message = "42",
            )
        )

        assertEquals(1, writer.writes.size)
        assertTrue(writer.writes.all { it.second == G1Side.LEFT })
        assertEquals(0x4B, writer.writes[0].first[0].toInt() and 0xFF)
    }

    @Test
    fun messageIdIncrementsPerNotificationAndWrapsAt255() = runTest {
        val sender = G1NotificationSender(G1CommandTransport(FakeWriter()))
        // First id is 1; the 255th call returns 255, then it wraps to 0.
        assertEquals(1, sender.nextMessageId())
        repeat(253) { sender.nextMessageId() }
        assertEquals(255, sender.nextMessageId())
        assertEquals(0, sender.nextMessageId())
        assertEquals(1, sender.nextMessageId())
    }

    @Test
    fun consecutiveNotificationsCarryIncrementingHeaderIds() = runTest {
        val writer = FakeWriter()
        val sender = G1NotificationSender(G1CommandTransport(writer), nowMillis = { 0L })
        repeat(3) { index ->
            sender.sendNotification("com.example.app", "App", "T$index", "", "M")
        }
        val ids = writer.writes.map { it.first[1].toInt() and 0xFF }
        assertEquals(listOf(1, 2, 3), ids)
    }

    @Test
    fun whitelistGoesToTheLeftLensOnly() = runTest {
        val writer = FakeWriter()
        val sender = G1NotificationSender(G1CommandTransport(writer))

        assertTrue(
            sender.sendWhitelist(
                listOf(G1CommandEncoder.WhitelistApp(id = "com.artjiang.helix", name = "Helix"))
            )
        )
        assertTrue(writer.writes.all { it.second == G1Side.LEFT })
        assertEquals(0x04, writer.writes[0].first[0].toInt() and 0xFF)
    }

    @Test
    fun notificationRetriesSixTimesBeforeGivingUp() = runTest {
        // Every write fails, so each attempt sends exactly one packet.
        val writer = FakeWriter(failFrom = 1)
        val sender = G1NotificationSender(G1CommandTransport(writer), nowMillis = { 0L })

        assertFalse(sender.sendNotification("com.example.app", "App", "T", "", "M"))
        assertEquals(G1NotificationSender.NOTIFY_ATTEMPTS, writer.writes.size)
    }

    @Test
    fun whitelistRetriesThreeTimesBeforeGivingUp() = runTest {
        val writer = FakeWriter(failFrom = 1)
        val sender = G1NotificationSender(G1CommandTransport(writer))

        assertFalse(sender.sendWhitelist(emptyList()))
        assertEquals(G1NotificationSender.WHITELIST_ATTEMPTS, writer.writes.size)
    }

    @Test
    fun retryPolicyMatchesTheOfficialReference() {
        assertEquals(6, G1NotificationSender.NOTIFY_ATTEMPTS)
        assertEquals(1_000L, G1NotificationSender.NOTIFY_BACKOFF_MILLIS)
        assertEquals(3, G1NotificationSender.WHITELIST_ATTEMPTS)
        assertEquals(300L, G1NotificationSender.WHITELIST_BACKOFF_MILLIS)
    }
}
