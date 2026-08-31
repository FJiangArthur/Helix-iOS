package com.artjiang.helix

import com.artjiang.helix.g1.G1HudDeliveryEvent
import com.artjiang.helix.g1.G1HudDeliveryStatus
import com.artjiang.helix.g1.G1ScreenDeliveryCoverage
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome

/**
 * Truthful phone-side state for one answer's route to the glasses.
 *
 * HUD pages are also a local preview, so their mere presence cannot prove that
 * any BLE packet was acknowledged. This receipt is updated only by the
 * ACK-backed [com.artjiang.helix.g1.G1HudSession] callback (or explicitly to
 * [PHONE_ONLY] while disconnected).
 */
enum class HudDeliveryPhase {
    IDLE,
    SENDING,
    DELIVERED,
    PARTIAL,
    FAILED,
    REFUSED,
    PHONE_ONLY,
}

data class HudDeliveryReceipt(
    /** Feed answer this receipt belongs to; null for notices/transcript previews. */
    val ownerFeedEntryId: Long? = null,
    /** Multi-question batches share one ACK lifecycle across all included cards. */
    val answerFeedEntryIds: Set<Long> = ownerFeedEntryId?.let(::setOf) ?: emptySet(),
    val phase: HudDeliveryPhase = HudDeliveryPhase.IDLE,
    val pageIndex: Int = 0,
    val pageCount: Int = 0,
    /** Exact ACK-backed left/right result for the most recent page push. */
    val screenOutcome: G1ScreenDeliveryOutcome? = null,
    /** Per-lens transport diagnostic, never user text. */
    val outcome: String = "",
) {
    /** User-facing answer badge. A different answer never inherits this receipt. */
    fun labelForAnswer(feedEntryId: Long): String? {
        if (ownerFeedEntryId != feedEntryId && feedEntryId !in answerFeedEntryIds) return null
        return when (phase) {
            HudDeliveryPhase.IDLE -> null
            HudDeliveryPhase.SENDING -> "Sending to glasses…"
            HudDeliveryPhase.DELIVERED -> {
                val safeCount = pageCount.coerceAtLeast(1)
                val safeIndex = pageIndex.coerceIn(0, safeCount - 1)
                "Delivered to glasses · page ${safeIndex + 1} of $safeCount"
            }
            HudDeliveryPhase.PARTIAL -> {
                val safeCount = pageCount.coerceAtLeast(1)
                val safeIndex = pageIndex.coerceIn(0, safeCount - 1)
                val destination = when (screenOutcome?.coverage) {
                    G1ScreenDeliveryCoverage.LEFT_ONLY -> "left lens only"
                    G1ScreenDeliveryCoverage.RIGHT_ONLY -> "right lens only"
                    else -> "one lens only"
                }
                "Delivered to $destination · page ${safeIndex + 1} of $safeCount"
            }
            HudDeliveryPhase.FAILED -> "Glasses delivery failed"
            HudDeliveryPhase.REFUSED -> "Glasses display busy"
            HudDeliveryPhase.PHONE_ONLY -> "Phone only"
        }
    }
}

/** Maps one session callback without erasing its typed per-lens result. */
internal fun HudDeliveryReceipt.applying(event: G1HudDeliveryEvent): HudDeliveryReceipt =
    copy(
        phase = when (event.status) {
            G1HudDeliveryStatus.DELIVERED -> HudDeliveryPhase.DELIVERED
            G1HudDeliveryStatus.PARTIAL -> HudDeliveryPhase.PARTIAL
            G1HudDeliveryStatus.FAILED -> HudDeliveryPhase.FAILED
            G1HudDeliveryStatus.REFUSED -> HudDeliveryPhase.REFUSED
        },
        pageIndex = event.pageIndex,
        pageCount = event.pageCount,
        screenOutcome = event.screenOutcome,
        outcome = event.screenOutcome?.diagnostic() ?: when (event.status) {
            G1HudDeliveryStatus.REFUSED -> "Display request refused before a screen write."
            else -> "No per-lens transport outcome was supplied."
        },
    )
