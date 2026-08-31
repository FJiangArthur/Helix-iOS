// Send path for the two notification commands (0x4B push, 0x04 whitelist).
//
// Both go to the LEFT lens only and carry their own retry policy — neither is
// ACK-gated through G1CommandTransport's generic path, because the firmware
// answers them with a plain result frame the reference implementation only ever
// checks for timeout. So the whole packet list is re-sent on failure, matching
// EvenDemoApp's `BleManager.requestList(..., lr: "L")` loop.
package com.artjiang.helix.notify

import com.artjiang.helix.g1.G1Command
import com.artjiang.helix.g1.G1CommandEncoder
import com.artjiang.helix.g1.G1CommandTransport
import com.artjiang.helix.g1.G1Side
import kotlinx.coroutines.delay

/**
 * Pushes phone notifications and the app whitelist to the glasses.
 *
 * ## Retry policy (from the official `Proto`)
 * | command | attempts | reference |
 * |---------|----------|-----------|
 * | 0x4B notification | [NOTIFY_ATTEMPTS] (6) | `sendNotify(retry: 6)`, 1000 ms |
 * | 0x04 whitelist    | [WHITELIST_ATTEMPTS] (3) | `sendNewAppWhiteListJson`, 300 ms |
 *
 * The reference's per-attempt timeout is the ACK wait; here the writes are
 * unacked and a failure surfaces as `write() == false` from the BLE stack, so
 * the timeout becomes the backoff between attempts. That is the one behavioural
 * deviation and it is not verifiable without hardware — see the agent report.
 */
class G1NotificationSender(
    private val transport: G1CommandTransport,
    /** Injected so tests need no real clock. */
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    /** Wraps at 255, matching the reference's single-byte `notifyId`. */
    private var messageIdCounter: Int = 0

    /** The next msg_id, wrapping 0..255. Visible for tests. */
    internal fun nextMessageId(): Int {
        messageIdCounter = (messageIdCounter + 1) and 0xFF
        return messageIdCounter
    }

    /**
     * Sends one notification (0x4B) to the left lens, retrying the whole packet
     * list up to [NOTIFY_ATTEMPTS] times.
     *
     * @return true once every packet was accepted by the stack.
     */
    suspend fun sendNotification(
        appId: String,
        displayName: String,
        title: String,
        subtitle: String,
        message: String,
    ): Boolean {
        val packets = G1CommandEncoder.notification(
            messageId = nextMessageId(),
            appIdentifier = appId,
            displayName = displayName,
            title = title,
            subtitle = subtitle,
            message = message,
            epochMillis = nowMillis(),
        )
        return sendLeft(packets, attempts = NOTIFY_ATTEMPTS, backoffMillis = NOTIFY_BACKOFF_MILLIS)
    }

    /**
     * Sends the app whitelist (0x04) to the left lens, retrying up to
     * [WHITELIST_ATTEMPTS] times. An empty list is still sent — that is how the
     * user clears the glasses' side of the filter.
     */
    suspend fun sendWhitelist(apps: List<G1CommandEncoder.WhitelistApp>): Boolean {
        val packets = G1CommandEncoder.notificationWhitelist(apps)
        return sendLeft(packets, attempts = WHITELIST_ATTEMPTS, backoffMillis = WHITELIST_BACKOFF_MILLIS)
    }

    private suspend fun sendLeft(
        packets: List<ByteArray>,
        attempts: Int,
        backoffMillis: Long,
    ): Boolean {
        repeat(attempts) { attempt ->
            var allWritten = true
            for (packet in packets) {
                val ok = transport.send(
                    G1Command(bytes = packet, sides = listOf(G1Side.LEFT)),
                )
                if (!ok) {
                    allWritten = false
                    // A failed write means the link is down; the remaining
                    // packets of this attempt would fail too.
                    break
                }
            }
            if (allWritten) return true
            if (attempt < attempts - 1) delay(backoffMillis)
        }
        return false
    }

    companion object {
        const val NOTIFY_ATTEMPTS = 6
        const val WHITELIST_ATTEMPTS = 3

        /** `sendNotify` uses a 1000 ms per-attempt timeout. */
        const val NOTIFY_BACKOFF_MILLIS: Long = 1_000

        /** `sendNewAppWhiteListJson` uses a 300 ms per-attempt timeout. */
        const val WHITELIST_BACKOFF_MILLIS: Long = 300
    }
}
