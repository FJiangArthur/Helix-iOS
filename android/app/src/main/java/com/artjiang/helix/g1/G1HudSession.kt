// The HUD answer lifecycle: paint, dwell, clear.
//
// WIRE BEHAVIOUR follows docs/G1_PROTOCOL_SLA.md, derived from the official
// EvenDemoApp vendor source:
//
//   * Vendor plain text paints every page with screen_status 0x71
//     (SIMPLE_TEXT | NEW_CONTENT), retaining 1-based page headers.
//   * 0x31/0x41/0x51 are a separate AI-session path and remain available to
//     explicit callers; this class presents ordinary Helix text via 0x71.
//
// BLANKING. iOS never blanks the HUD at all — content sits on the lens until
// something overwrites it. The "answer disappears after a few seconds" the
// product wants is therefore NEW behaviour on both platforms, and cannot be
// obtained by copying iOS. It is implemented here as an explicit 0x18
// EXIT_ALL_FUNCTIONS after the dwell, which clears the screen and returns the
// lens to the firmware dashboard. That is the desired end state: the wearer
// looks up, reads the answer, and the HUD goes away.
//
// Emitted sequences:
//   single page : 0x71, wait [completeDelayMillis], 0x18
//   multi page  : 0x71 page 1, 0x71 per page every [autoAdvanceMillis],
//                 then wait [completeDelayMillis] on the last page, then 0x18
//   touchpad    : cancels every timer and latches manual mode; each page goes
//                 out at 0x71 and NO automatic 0x18 follows — once the wearer
//                 is paging by hand they own the screen until they exit or new
//                 content arrives.
package com.artjiang.helix.g1

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** ACK-backed outcome for one screen push in a HUD delivery. */
enum class G1HudDeliveryStatus { DELIVERED, PARTIAL, FAILED, REFUSED }

data class G1HudDeliveryEvent(
    /** Caller-provided token; lets the bridge ignore a superseded answer. */
    val deliveryId: Long,
    val status: G1HudDeliveryStatus,
    val pageIndex: Int,
    val pageCount: Int,
    /** Present for an attempted screen write; null when the arbiter refused it. */
    val screenOutcome: G1ScreenDeliveryOutcome? = null,
)

/**
 * Drives one answer's HUD lifecycle.
 *
 * Pure Kotlin (no android.*), so the whole state machine is unit-testable on
 * virtual time with a fake [sendScreen].
 *
 * Threading: every mutation runs on [scope], which the bridge backs with a
 * single-threaded main dispatcher, so the mutable fields need no extra lock.
 * Writes are serialized by the caller's transport (`sendScreen` holds the
 * transport queue lock for a whole screen, including the load-bearing 400 ms
 * inter-side settle), and a new push always cancels the in-flight job first,
 * so two pages can never interleave packets.
 *
 * @param sendScreen writes one already-encoded screen and preserves its
 *        per-lens ACK result. A partial one-lens success continues the
 *        lifecycle, but remains partial in every delivery event; a failed
 *        write aborts rather than scheduling a completion the glasses could
 *        not act on.
 * @param requestDisplay HUD arbiter gate. Every push asks again, so a
 *        higher-priority producer can take the display mid-answer.
 */
class G1HudSession(
    private val scope: CoroutineScope,
    private val sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    private val requestDisplay: suspend () -> Boolean = { true },
    private val releaseDisplay: suspend () -> Unit = {},
    /**
     * Blanks the lens (0x18). Called once the answer's dwell expires; the
     * firmware returns to its dashboard, which is what the wearer expects
     * after the answer has been read.
     */
    private val clearScreen: suspend () -> Unit = {},
    private val onPageChanged: (Int) -> Unit = {},
    /** Emitted only after the arbiter decision / ACK-backed screen write. */
    private val onDeliveryChanged: (G1HudDeliveryEvent) -> Unit = {},
    /**
     * How long a finished answer stays on the lens before it is cleared. Read
     * per answer so a settings change applies to the next one without
     * rebuilding the session.
     */
    private val completeDelayMillis: () -> Long = { SINGLE_PAGE_COMPLETE_DELAY_MILLIS },
    private val autoAdvanceMillis: () -> Long = { AUTO_ADVANCE_INTERVAL_MILLIS },
) {
    companion object {
        /** Default dwell: how long the finished answer stays readable. */
        const val SINGLE_PAGE_COMPLETE_DELAY_MILLIS: Long = 3_000

        /**
         * Official `EvenAI.updateReplyToOSByTimer`: `int interval = 5;` — the
         * auto-advance period for a multi-page answer.
         */
        const val AUTO_ADVANCE_INTERVAL_MILLIS: Long = 5_000
    }

    /** Phase of the currently displayed answer. */
    enum class Phase { IDLE, DISPLAYING, MANUAL, COMPLETE }

    var phase: Phase = Phase.IDLE
        private set

    /** 0-based index of the page currently on the glasses. */
    var pageIndex: Int = 0
        private set

    /** Pages of the answer currently owning the HUD. */
    var pages: List<G1HudPage> = emptyList()
        private set

    /**
     * Per-SCREEN counter, header byte 1. The official app increments it once
     * per screen push (`Proto._evenaiSeq++`) and masks to a byte.
     */
    private var syncSeq: Int = 0

    private var lifecycleJob: Job? = null

    /** Token for [pages], supplied by the caller of [present]. */
    private var deliveryId: Long = 0

    val isActive: Boolean
        get() = phase == Phase.DISPLAYING || phase == Phase.MANUAL

    /**
     * Starts the official lifecycle for [answerPages].
     *
     * Cancels anything the previous answer had scheduled — a new answer always
     * wins, and a stale 0x41 landing after it would blank the new content.
     */
    fun present(answerPages: List<G1HudPage>, deliveryId: Long = 0) {
        if (answerPages.isEmpty()) {
            cancelTimers()
            reset()
            return
        }
        // Ask FIRST, tear down second. Cancelling the running lifecycle before
        // knowing whether the new content may draw would orphan its pending
        // clear, and nothing else would ever blank the lens.
        scope.launch {
            if (!requestDisplay()) {
                onDeliveryChanged(
                    G1HudDeliveryEvent(
                        deliveryId,
                        G1HudDeliveryStatus.REFUSED,
                        pageIndex = 0,
                        pageCount = answerPages.size,
                    ),
                )
                return@launch
            }
            // Granted: only now does the previous lifecycle lose its claim, and
            // only now do we become the tracked job. A refused newcomer leaves
            // the running lifecycle (and its pending clear) untouched.
            val owner = coroutineContext[Job] ?: return@launch
            lifecycleJob?.cancel()
            lifecycleJob = owner
            pages = answerPages
            this@G1HudSession.deliveryId = deliveryId
            pageIndex = 0
            phase = Phase.DISPLAYING
            onPageChanged(0)

            // SLA-A5: every plain-text page carries 0x71. Pagination remains
            // explicit in the 1-based currentPage/maxPage header.
            val initialOutcome = push(0, G1ScreenStatus.NEW_CONTENT_PAGE)
            if (!initialOutcome.isSuccessful) {
                if (!owns(owner)) return@launch
                reportDelivery(initialOutcome.deliveryStatus, 0, initialOutcome)
                // A failed peer lens makes this lifecycle unsafe to continue,
                // even when the other side ACKed. Preserve that partial truth
                // in the receipt, then give the lease back rather than
                // auto-advancing two lenses that no longer share a page.
                pages = emptyList()
                pageIndex = 0
                phase = Phase.IDLE
                releaseDisplay()
                if (owns(owner)) lifecycleJob = null
                return@launch
            }
            if (!owns(owner)) return@launch
            reportDelivery(initialOutcome.deliveryStatus, 0, initialOutcome)

            if (pages.size > 1) {
                // Auto-advance through the middle pages.
                while (owns(owner) && phase == Phase.DISPLAYING && pageIndex < pages.size - 1) {
                    delay(autoAdvanceMillis())
                    if (!owns(owner) || phase != Phase.DISPLAYING) return@launch
                    val next = pageIndex + 1
                    pageIndex = next
                    onPageChanged(next)
                    val nextOutcome = push(next, G1ScreenStatus.NEW_CONTENT_PAGE)
                    if (!nextOutcome.isSuccessful) {
                        if (!owns(owner)) return@launch
                        reportDelivery(nextOutcome.deliveryStatus, next, nextOutcome)
                        pages = emptyList()
                        pageIndex = 0
                        phase = Phase.IDLE
                        releaseDisplay()
                        if (owns(owner)) lifecycleJob = null
                        return@launch
                    }
                    if (!owns(owner)) return@launch
                    reportDelivery(nextOutcome.deliveryStatus, next, nextOutcome)
                }
            }

            // Dwell on the last page, then blank.
            delay(completeDelayMillis())
            // The wearer may have grabbed the screen during the dwell; manual
            // mode owns the display from then on and must not be cleared.
            if (!owns(owner) || phase != Phase.DISPLAYING) return@launch
            // The lease is released whether or not the clear itself lands.
            // Gating release on the clear would re-create the stuck-lease bug
            // one step later: a failed blank (a lens dropping mid-teardown)
            // would hold the HUD for the rest of the ANSWER window and lock
            // out every notification behind it.
            try {
                clearScreen()
            } catch (cancellation: kotlinx.coroutines.CancellationException) {
                // A newer answer superseded us mid-teardown: it owns the lens
                // and the lease now, so release nothing and let it unwind.
                throw cancellation
            } catch (_: Throwable) {
                // A blank that failed (a lens dropping) is not worth crashing
                // the bridge scope over; the lease still has to come back.
            } finally {
                // Cancellation can resume this finally after a replacement
                // answer has acquired the lifecycle. The old clear must never
                // complete or release that newer owner.
                if (owns(owner)) {
                    phase = Phase.COMPLETE
                    releaseDisplay()
                    if (owns(owner)) lifecycleJob = null
                }
            }
        }
    }

    /**
     * Touchpad / UI paging. Latches manual mode: all auto-advance timers stop
     * and no 0x41 is ever sent for this answer, so the wearer keeps the screen
     * until they exit or new content arrives.
     *
     * Pages go out at 0x71 like every plain-text page. Latching MANUAL also
     * cancels the pending clear, so hand-paged content stays up.
     */
    fun showPage(index: Int) {
        if (pages.isEmpty()) return
        cancelTimers()
        phase = Phase.MANUAL
        pageIndex = index.coerceIn(0, pages.size - 1)
        onPageChanged(pageIndex)
        val target = pageIndex
        // Register ownership before starting: Main.immediate can otherwise run
        // an uncontended requestDisplay all the way to the ownership check
        // before launch() returns and assigns lifecycleJob.
        val manualJob = scope.launch(start = CoroutineStart.LAZY) {
            val owner = coroutineContext[Job] ?: return@launch
            if (!requestDisplay()) {
                if (!owns(owner)) return@launch
                reportDelivery(G1HudDeliveryStatus.REFUSED, target)
                return@launch
            }
            if (!owns(owner)) return@launch
            val outcome = push(target, G1ScreenStatus.NEW_CONTENT_PAGE)
            if (!owns(owner)) return@launch
            reportDelivery(outcome.deliveryStatus, target, outcome)
        }
        lifecycleJob = manualJob
        manualJob.start()
    }

    fun showNextPage() = showPage(pageIndex + 1)

    fun showPreviousPage() = showPage(pageIndex - 1)

    /** Cancels every scheduled push and forgets the answer (stop / disconnect / exit). */
    fun reset() {
        cancelTimers()
        pages = emptyList()
        pageIndex = 0
        phase = Phase.IDLE
    }

    private fun cancelTimers() {
        lifecycleJob?.cancel()
        lifecycleJob = null
    }

    private fun owns(job: Job): Boolean = lifecycleJob === job

    private suspend fun push(index: Int, status: G1ScreenStatus): G1ScreenDeliveryOutcome {
        val page = pages.getOrNull(index) ?: return G1ScreenDeliveryOutcome.failed(packetCount = 0)
        syncSeq = (syncSeq + 1) and 0xFF
        return sendScreen(G1HudPresenter.repacketize(page, status, syncSeq.toByte()))
    }

    private val G1ScreenDeliveryOutcome.deliveryStatus: G1HudDeliveryStatus
        get() = when (coverage) {
            G1ScreenDeliveryCoverage.BOTH -> G1HudDeliveryStatus.DELIVERED
            G1ScreenDeliveryCoverage.LEFT_ONLY,
            G1ScreenDeliveryCoverage.RIGHT_ONLY -> G1HudDeliveryStatus.PARTIAL
            G1ScreenDeliveryCoverage.NONE -> G1HudDeliveryStatus.FAILED
        }

    private fun reportDelivery(
        status: G1HudDeliveryStatus,
        index: Int,
        outcome: G1ScreenDeliveryOutcome? = null,
    ) {
        onDeliveryChanged(
            G1HudDeliveryEvent(
                deliveryId = deliveryId,
                status = status,
                pageIndex = index,
                pageCount = pages.size,
                screenOutcome = outcome,
            ),
        )
    }
}
