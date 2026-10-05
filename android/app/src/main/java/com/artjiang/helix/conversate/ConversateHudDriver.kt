// Sends Conversate screens to the G1 (spec §5.3). Renders STATE, not events:
// a conflated slot means a burst of updates draws only the newest frame.
// Persistent: nothing here blanks the lens on a timer — clearing happens only
// when the session submits a null frame (or shutdown()).
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.g1.G1PacketEncoder
import com.artjiang.helix.g1.G1ScreenDeliveryCoverage
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull

class ConversateHudDriver(
    scope: CoroutineScope,
    private val sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    private val clearScreen: suspend () -> Unit,
    private val arbiter: HudArbiter,
    private val clock: () -> Long,
    private val captionIntervalMillis: () -> Long = { CAPTION_INTERVAL_DEFAULT_MILLIS },
) {
    companion object {
        /** Replace with max(700, S3 p90 + 100) once spike S3 is recorded. */
        const val CAPTION_INTERVAL_DEFAULT_MILLIS = 700L
        const val LEASE_RENEW_MILLIS = 20_000L
        const val RETRY_BACKOFF_MILLIS = 2_000L
    }

    private data class Submission(val frame: HudFrame?, val interactive: Boolean)
    private object Unset

    private val slot = Channel<Submission>(Channel.CONFLATED)
    private val lock = Mutex()
    private var lease: HudArbiter.Lease? = null
    private var last: Any? = Unset
    private var lastSentAt = Long.MIN_VALUE / 2
    private var syncSeq = 0
    private var heldPriority = HudArbiter.Priority.CONVERSATE_LIVE
    @Volatile
    private var forceRedraw = false
    private var failedFrame: HudFrame? = null
    private var failedAt = Long.MIN_VALUE / 2
    private val lastSentState = MutableStateFlow<String?>(null)
    val lastSentText: StateFlow<String?> = lastSentState.asStateFlow()

    init {
        scope.launch {
            for (first in slot) {
                var next = first
                // A caption waits out the cadence; anything newer replaces it,
                // and an interactive screen (or a clear) ends the wait at once.
                while (!next.interactive && next.frame != null) {
                    val wait = lastSentAt + captionIntervalMillis() - clock()
                    if (wait <= 0) break
                    next = withTimeoutOrNull(wait) { slot.receive() } ?: break
                }
                lock.withLock { draw(next) }
            }
        }
        scope.launch {
            while (true) {
                delay(LEASE_RENEW_MILLIS)
                renew()
            }
        }
    }

    /** Forget what the lens shows so the next frame is sent even if identical. */
    fun invalidate() {
        forceRedraw = true
    }

    fun submit(frame: HudFrame?, interactive: Boolean) {
        slot.trySend(Submission(frame, interactive))
    }

    /** Clears the lens and gives the HUD back. Safe to call repeatedly. */
    suspend fun shutdown() = lock.withLock {
        if (last != null && last !== Unset) clearScreen()
        lease?.let { arbiter.release(it) }
        lease = null
        // The lens is blank now: a later blank frame must not clear again.
        last = null
        lastSentState.value = null
    }

    private suspend fun draw(s: Submission) {
        if (!forceRedraw && s.frame == last) return
        // Disconnected glasses: don't hammer the transport with the same frame.
        if (s.frame != null && s.frame == failedFrame && clock() - failedAt < RETRY_BACKOFF_MILLIS) return
        forceRedraw = false
        if (s.frame == null) {
            clearScreen()
            lease?.let { arbiter.release(it) }
            lease = null
            last = null
            lastSentState.value = null
            return
        }
        val priority = if (s.interactive) HudArbiter.Priority.CONVERSATE_INTERACTIVE else HudArbiter.Priority.CONVERSATE_LIVE
        // Passing our own lease lets a closed menu (INTERACTIVE) step back
        // down to captions (LIVE) instead of being refused by itself.
        val granted = arbiter.acquire(priority, replacing = lease) ?: return
        lease = granted
        heldPriority = priority
        syncSeq = (syncSeq + 1) and 0xFF
        val packets = G1PacketEncoder.encodeTextPage(
            text = s.frame.text,
            currentPage = s.frame.page,
            maxPage = s.frame.pageCount,
            syncSeq = syncSeq.toByte(),
        )
        val outcome = try {
            sendScreen(packets)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        }
        // Remember the frame only if a lens took it; otherwise the
        // identical-frame guard would block the retry.
        if (outcome == null || outcome.coverage == G1ScreenDeliveryCoverage.NONE) {
            failedFrame = s.frame
            failedAt = clock()
            return
        }
        failedFrame = null
        last = s.frame
        lastSentAt = clock()
        lastSentState.value = s.frame.text
    }

    /** Re-acquires the held lease so a long-open menu never expires under the wearer. */
    private suspend fun renew() = lock.withLock {
        val held = lease ?: return@withLock
        lease = arbiter.acquire(heldPriority, replacing = held) ?: held
    }
}
