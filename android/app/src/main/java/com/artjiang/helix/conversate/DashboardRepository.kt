// Relay-backed dashboard data for the G1 panels (plan D2). One /dashboard
// fetch feeds all four panels; it is cached for [ttlMillis] so paging between
// panels does not hammer the relay (which itself rate-limits Omi).
package com.artjiang.helix.conversate

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class DashboardRepository(
    private val fetch: suspend () -> RelayDashboard,
    private val clock: () -> Long = System::currentTimeMillis,
    private val ttlMillis: Long = 60_000,
) {
    private val lock = Mutex()
    private var cached: RelayDashboard? = null
    private var fetchedAt = Long.MIN_VALUE / 2

    /**
     * The dashboard, refetched once the cache is older than [ttlMillis]. A
     * failed refresh keeps serving the last good copy; with nothing cached
     * the [RelayException] propagates.
     */
    suspend fun dashboard(): RelayDashboard = lock.withLock {
        val now = clock()
        val fresh = cached?.takeIf { now - fetchedAt < ttlMillis }
        if (fresh != null) return@withLock fresh
        try {
            fetch().also { cached = it; fetchedAt = now }
        } catch (e: RelayException) {
            cached ?: throw e
        }
    }

    suspend fun rows(kind: String): List<PanelRow> = dashboard().rows(kind)

    /** Mirrors a to-do check-off locally so a re-opened panel agrees with the lens. */
    suspend fun applyToggle(id: String, done: Boolean) = lock.withLock {
        cached = cached?.let { d -> d.copy(todos = d.todos.map { if (it.id == id) it.copy(completed = done) else it }) }
    }

    suspend fun invalidate() = lock.withLock { cached = null }
}
