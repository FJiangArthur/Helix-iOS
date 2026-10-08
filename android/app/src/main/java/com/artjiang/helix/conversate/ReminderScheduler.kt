// Polls helix-relay /reminders while the app runs (plan D2) and hands each
// new reminder to [deliver] exactly once. Time comes from the coroutine
// scheduler (delay) plus [clock], so tests drive it with virtual time.
package com.artjiang.helix.conversate

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class ReminderScheduler(
    private val scope: CoroutineScope,
    private val fetch: suspend (sinceMillis: Long) -> List<RelayReminder>,
    private val deliver: (RelayReminder) -> Unit,
    private val clock: () -> Long = System::currentTimeMillis,
    private val isConfigured: () -> Boolean = { true },
    private val intervalMillis: Long = INTERVAL_MILLIS,
) {
    companion object {
        const val INTERVAL_MILLIS = 5 * 60_000L
        private const val MAX_SEEN = 500
    }

    private val seen = LinkedHashSet<String>()
    private var since: Long? = null
    private var job: Job? = null

    fun start() {
        if (job?.isActive == true) return
        job = scope.launch {
            while (isActive) {
                pollOnce()
                delay(intervalMillis)
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    private suspend fun pollOnce() {
        if (!isConfigured()) return
        val now = clock()
        val from = since ?: (now - intervalMillis)
        val reminders = try {
            fetch(from)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // Relay asleep / tailnet down: try again next round from the same mark.
            if (since == null) since = from
            return
        }
        since = now
        reminders.forEach { reminder ->
            if (seen.add(reminder.id)) deliver(reminder)
        }
        while (seen.size > MAX_SEEN) seen.remove(seen.first())
    }
}
