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
    }

    private val mutex = Mutex()
    private var activePriority: Priority? = null
    private var activeUntilMillis: Long = 0

    /**
     * @return true when the caller may draw.
     * @param durationMillis how long this producer holds the HUD; defaults come
     *        from [defaultDurationFor].
     */
    suspend fun requestDisplay(
        priority: Priority,
        durationMillis: Long = defaultDurationFor(priority),
    ): Boolean = mutex.withLock {
        val now = clock()
        val current = activePriority
        val expired = current == null || activeUntilMillis <= now

        if (current != null && !expired && priority.rank < current.rank) return@withLock false

        activePriority = priority
        activeUntilMillis = now + durationMillis
        true
    }

    suspend fun releaseDisplay() = mutex.withLock {
        activePriority = null
        activeUntilMillis = 0
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

        fun defaultDurationFor(priority: Priority): Long = when (priority) {
            Priority.ANSWER -> ANSWER_DURATION_MILLIS
            Priority.NOTIFICATION -> NOTIFICATION_DURATION_MILLIS
            Priority.INSIGHT -> INSIGHT_DURATION_MILLIS
            Priority.DASHBOARD -> DASHBOARD_DURATION_MILLIS
        }
    }
}
