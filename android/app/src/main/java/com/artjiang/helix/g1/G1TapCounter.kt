package com.artjiang.helix.g1

/**
 * Software multi-tap detection for the G1 touchpad.
 *
 * WHY THIS EXISTS: the firmware has no triple-tap event. Every reference
 * implementation — the official EvenDemoApp's own handler
 * (`lib/ble_manager.dart:154-175`) and this app's decoder — sees only four
 * inbound `0xF5` notify indices: 0 (exit), 1 (single tap), 23 (evenAI start)
 * and 24 (record over). A triple tap therefore arrives as three separate
 * index-1 frames and must be recognised on the phone by their timing.
 *
 * Pure and clock-injected so the whole window/threshold behaviour is testable
 * on virtual time — no android.* imports, no real delays.
 *
 * ## Why taps are reported on a trailing timer rather than instantly
 * A tap cannot be classified the moment it lands: the third tap of a triple is
 * indistinguishable from the first tap of a single until [multiTapWindowMillis]
 * has passed with no successor. [onTap] therefore only accumulates; the caller
 * polls [pollExpired] (or the bridge schedules a wake) once the window closes,
 * and the burst is reported then. That trailing delay is inherent to multi-tap
 * on any platform, which is why single-tap actions on this pad feel slightly
 * lazier once multi-tap is enabled.
 */
class G1TapCounter(
    /**
     * Maximum gap between taps of one burst. 400 ms is the usual comfortable
     * multi-tap window: long enough for a deliberate triple tap through the
     * glasses' arm, short enough that two unrelated taps seconds apart are not
     * merged.
     */
    private val multiTapWindowMillis: Long = DEFAULT_MULTI_TAP_WINDOW_MILLIS,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    companion object {
        const val DEFAULT_MULTI_TAP_WINDOW_MILLIS: Long = 400
    }

    /** A completed burst: how many taps landed, and on which pad. */
    data class Burst(val count: Int, val side: G1TouchpadSide)

    private var pendingSide: G1TouchpadSide? = null
    private var pendingCount: Int = 0
    private var lastTapAt: Long = 0

    /**
     * Records one tap. Returns the burst that this tap *ended* — which is the
     * burst accumulated on the OTHER pad, or a stale burst on this pad whose
     * window had already closed — or null when the tap merely extends the
     * current burst.
     *
     * Switching pads mid-burst flushes the old one rather than discarding it,
     * so a left tap immediately after two right taps still reports the double.
     */
    fun onTap(side: G1TouchpadSide, now: Long = clock()): Burst? {
        val expired = pollExpired(now)
        if (pendingSide != null && pendingSide != side) {
            // Different pad: flush what we had, then start fresh on this one.
            val flushed = Burst(pendingCount, pendingSide!!)
            pendingSide = side
            pendingCount = 1
            lastTapAt = now
            return expired ?: flushed
        }
        pendingSide = side
        pendingCount += 1
        lastTapAt = now
        return expired
    }

    /**
     * Reports a burst whose multi-tap window has closed, or null when none has.
     * Call after [multiTapWindowMillis] has elapsed since the last tap.
     */
    fun pollExpired(now: Long = clock()): Burst? {
        val side = pendingSide ?: return null
        if (now - lastTapAt < multiTapWindowMillis) return null
        val burst = Burst(pendingCount, side)
        reset()
        return burst
    }

    /** Milliseconds until the pending burst can be reported, or null if idle. */
    fun millisUntilExpiry(now: Long = clock()): Long? {
        if (pendingSide == null) return null
        return (lastTapAt + multiTapWindowMillis - now).coerceAtLeast(0)
    }

    fun reset() {
        pendingSide = null
        pendingCount = 0
        lastTapAt = 0
    }
}
