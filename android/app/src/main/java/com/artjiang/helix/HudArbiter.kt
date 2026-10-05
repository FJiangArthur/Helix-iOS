// Single owner of the glasses HUD. Port of the `HudArbiter` actor in
// ios/Runner/HelixNativeBridge.swift.
package com.artjiang.helix

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Arbitrates the one physical HUD between competing producers.
 *
 * Higher priority preempts lower; an expired window frees the display for
 * anyone. Every grant carries a duration, so a producer that never draws again
 * cannot hold the HUD forever — the iOS version let an answer hold it
 * indefinitely (nil duration), which meant a stale answer could block insights
 * and notifications for the rest of the session.
 */
class HudArbiter(private val clock: () -> Long = System::currentTimeMillis) {

    enum class Priority(val rank: Int) {
        INSIGHT(0),
        DASHBOARD(1),
        NOTIFICATION(2),
        ANSWER(3),
        /** Conversate captions/cue cards: same rank as an answer (answers become cues). */
        CONVERSATE_LIVE(3),
        /** Conversate menu/panel/detail the wearer opened: nothing may draw over it. */
        CONVERSATE_INTERACTIVE(4),
    }

    /**
     * Proof of ownership. Only the current lease can release the HUD, so a
     * producer that was superseded can never blank a newer screen.
     */
    @JvmInline
    value class Lease(val generation: Long)

    private val mutex = Mutex()
    private var activePriority: Priority? = null
    private var activeUntilMillis: Long = 0
    private var generation: Long = 0

    /**
     * @return a lease when the caller may draw, null when refused.
     * @param durationMillis how long this producer holds the HUD; defaults come
     *        from [defaultDurationFor].
     * @param replacing the caller's current lease: a holder may always renew or
     *        change its own priority (e.g. a closed menu stepping back down to
     *        captions) instead of being refused by itself.
     */
    suspend fun acquire(
        priority: Priority,
        durationMillis: Long = defaultDurationFor(priority),
        replacing: Lease? = null,
    ): Lease? = mutex.withLock {
        val now = clock()
        val current = activePriority
        val expired = current == null || activeUntilMillis <= now
        val ownsIt = replacing != null && replacing.generation == generation && !expired

        // Strictly-lower priority is refused while a live window holds the HUD.
        // EQUAL priority always wins: a second answer (or a manual "Send to
        // glasses" of the same answer) is new content from the same producer,
        // and refusing it left the button silently doing nothing for 30 s.
        if (!ownsIt && current != null && !expired && priority.rank < current.rank) return@withLock null

        activePriority = priority
        activeUntilMillis = now + durationMillis
        generation += 1
        Lease(generation)
    }

    /** Boolean form of [acquire] for callers that never release explicitly. */
    suspend fun requestDisplay(
        priority: Priority,
        durationMillis: Long = defaultDurationFor(priority),
    ): Boolean = acquire(priority, durationMillis) != null

    /** Releases only if [lease] is still the holder; a superseded lease is a no-op. */
    suspend fun release(lease: Lease) = mutex.withLock {
        if (lease.generation != generation) return@withLock
        activePriority = null
        activeUntilMillis = 0
    }

    /** True while nobody has acquired or released since [lease] was granted (expiry ignored). */
    suspend fun isLatest(lease: Lease): Boolean = mutex.withLock {
        lease.generation == generation && activePriority != null
    }

    suspend fun isCurrent(lease: Lease): Boolean = mutex.withLock {
        lease.generation == generation && activePriority != null && activeUntilMillis > clock()
    }

    /** The holder right now, or null when the window has expired. */
    suspend fun currentHolder(): Priority? = mutex.withLock {
        if (activePriority != null && activeUntilMillis > clock()) activePriority else null
    }

    companion object {
        const val ANSWER_DURATION_MILLIS = 30_000L
        const val NOTIFICATION_DURATION_MILLIS = 10_000L
        const val INSIGHT_DURATION_MILLIS = 10_000L
        const val DASHBOARD_DURATION_MILLIS = 10_000L

        /** Conversate renews its lease on every screen and periodically while idle. */
        const val CONVERSATE_DURATION_MILLIS = 60_000L

        fun defaultDurationFor(priority: Priority): Long = when (priority) {
            Priority.ANSWER -> ANSWER_DURATION_MILLIS
            Priority.NOTIFICATION -> NOTIFICATION_DURATION_MILLIS
            Priority.INSIGHT -> INSIGHT_DURATION_MILLIS
            Priority.DASHBOARD -> DASHBOARD_DURATION_MILLIS
            Priority.CONVERSATE_LIVE, Priority.CONVERSATE_INTERACTIVE -> CONVERSATE_DURATION_MILLIS
        }
    }
}
