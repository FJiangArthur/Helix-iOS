package com.artjiang.helix.ai

/**
 * Rolling window of the last ~minute of finalized transcript, oldest first.
 * Fed by every transcript source; read by the on-demand "Ask now" path so the
 * model sees what was just said rather than a single detected question.
 *
 * Bounded twice: entries older than [windowMillis] are dropped, and the
 * total text is capped at [maxChars] (oldest first) so a chatty minute
 * cannot blow the prompt budget. Thread-safe — sources emit on any thread.
 */
class RecentTranscriptBuffer(
    private val windowMillis: Long = DEFAULT_WINDOW_MILLIS,
    private val maxChars: Int = DEFAULT_MAX_CHARS,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private data class Entry(val text: String, val at: Long)

    private val entries = ArrayDeque<Entry>()

    @Synchronized
    fun append(text: String, at: Long = clock()) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        entries.addLast(Entry(trimmed.takeLast(maxChars), at))
        trim(at)
    }

    /** Entries still inside the window as of [now], one per line, oldest first. */
    @Synchronized
    fun recent(now: Long = clock()): String {
        trim(now)
        return entries.joinToString("\n") { it.text }
    }

    @Synchronized
    fun isEmpty(now: Long = clock()): Boolean {
        trim(now)
        return entries.isEmpty()
    }

    @Synchronized
    fun clear() = entries.clear()

    private fun trim(now: Long) {
        val cutoff = now - windowMillis
        while (entries.isNotEmpty() && entries.first().at < cutoff) entries.removeFirst()
        var total = entries.sumOf { it.text.length } + (entries.size - 1).coerceAtLeast(0)
        while (entries.size > 1 && total > maxChars) {
            total -= entries.removeFirst().text.length + 1
        }
    }

    companion object {
        const val DEFAULT_WINDOW_MILLIS = 60_000L
        const val DEFAULT_MAX_CHARS = 2_000
    }
}
