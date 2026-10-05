// Conversate cues and the pending-cue queue (spec §4.4 + "Cue queue rules").
package com.artjiang.helix.conversate

enum class CueType(val priority: Int, val label: String) {
    ANSWER(5, "ANSWER"),
    QUOTE(4, "QUOTE"),
    HEADLINE(3, "NEWS"),
    BIO(2, "BIO"),
    CONCEPT(2, "CONCEPT"),
    SUGGESTION(1, "IDEA"),
    NOTICE(0, "NOTE"),
}

data class Cue(
    val id: Long,
    val type: CueType,
    val title: String,
    val body: String,
    val detail: String? = null,
    val entity: String? = null,
    val ticker: String? = null,
    val createdAtMillis: Long,
)

/**
 * Pending cues. Highest priority first, FIFO within a priority. Over
 * [capacity] the oldest lowest-priority non-ANSWER cue is evicted; ANSWERs are
 * never evicted (so the queue may exceed capacity). Cues older than
 * [staleMillis] are dropped on every access.
 */
class CueQueue(private val capacity: Int = 3, private val staleMillis: Long = 90_000) {
    private val items = mutableListOf<Cue>()
    private val order = compareByDescending<Cue> { it.type.priority }.thenBy { it.createdAtMillis }

    val size: Int get() = items.size

    fun offer(cue: Cue, now: Long) {
        prune(now)
        items += cue
        while (items.size > capacity) {
            val victim = items.filter { it.type != CueType.ANSWER }
                .minWithOrNull(compareBy<Cue> { it.type.priority }.thenBy { it.createdAtMillis })
                ?: break
            items.remove(victim)
        }
    }

    fun poll(now: Long): Cue? {
        prune(now)
        val next = items.sortedWith(order).firstOrNull() ?: return null
        items.remove(next)
        return next
    }

    fun count(now: Long): Int {
        prune(now)
        return items.size
    }

    fun clear() = items.clear()

    private fun prune(now: Long) {
        items.removeAll { now - it.createdAtMillis > staleMillis }
    }
}
