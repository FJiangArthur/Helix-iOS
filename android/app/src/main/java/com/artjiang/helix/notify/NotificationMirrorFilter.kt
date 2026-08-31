// Pure decision layer for phone→glasses notification mirroring.
//
// Deliberately free of android.* types so every rule below is JVM-testable and
// the NotificationListenerService stays a thin adapter: it converts a
// StatusBarNotification into [IncomingNotification] and asks this class whether
// to forward. No notification text is ever logged, here or in the service.
package com.artjiang.helix.notify

/**
 * One posted phone notification, reduced to the fields the decision needs.
 *
 * @param packageName the posting app's package id.
 * @param title notification title (may be blank).
 * @param text notification body (may be blank).
 * @param isOngoing true for persistent/foreground-service notifications
 *        (music transport, navigation, downloads) — never mirrored.
 * @param isGroupSummary true for the collapsed parent of a bundle, whose text
 *        duplicates the children ("3 new messages") — never mirrored.
 * @param postedAtMillis wall-clock post time, used for the dedupe window.
 */
data class IncomingNotification(
    val packageName: String,
    val title: String,
    val text: String,
    val isOngoing: Boolean = false,
    val isGroupSummary: Boolean = false,
    val postedAtMillis: Long,
)

/**
 * Decides which posted notifications reach the glasses.
 *
 * Rules, in order:
 *  1. Mirroring must be enabled and the package must be in the user's
 *     whitelist. Everything else is dropped before any content is touched.
 *  2. Ongoing and group-summary notifications are dropped — those are the two
 *     categories that fire repeatedly for a single user-visible event (a
 *     progress bar ticking, a bundle re-summarizing on every child).
 *  3. Identical (package, title, text) triples inside [dedupeWindowMillis] are
 *     dropped. Android re-posts the same notification on every trivial update
 *     (a chat app rewriting its own notification per typing indicator), and
 *     each repost would otherwise take the HUD for 10 seconds.
 *  4. Empty content is dropped — a HUD page with nothing on it is noise.
 *
 * Instances are not thread-safe; the listener service calls [shouldForward]
 * from the single binder callback thread.
 */
class NotificationMirrorFilter(
    private val dedupeWindowMillis: Long = DEFAULT_DEDUPE_WINDOW_MILLIS,
    private val maxRecentEntries: Int = DEFAULT_MAX_RECENT_ENTRIES,
) {
    /** Fingerprint -> when it was last forwarded. Pruned in [shouldForward]. */
    private val recentlyForwarded = LinkedHashMap<String, Long>()

    /**
     * @param enabled the user's "Mirror other apps" switch.
     * @param whitelist package ids the user ticked.
     * @return true when this notification should be forwarded to the glasses.
     */
    fun shouldForward(
        notification: IncomingNotification,
        enabled: Boolean,
        whitelist: Set<String>,
    ): Boolean {
        if (!enabled) return false
        if (notification.packageName !in whitelist) return false
        if (notification.isOngoing || notification.isGroupSummary) return false
        if (notification.title.isBlank() && notification.text.isBlank()) return false

        val key = fingerprint(notification)
        val now = notification.postedAtMillis
        prune(now)
        val lastSeen = recentlyForwarded[key]
        if (lastSeen != null && now - lastSeen < dedupeWindowMillis) return false

        // Re-insert so LinkedHashMap ordering stays newest-last for the cap.
        recentlyForwarded.remove(key)
        recentlyForwarded[key] = now
        if (recentlyForwarded.size > maxRecentEntries) {
            val oldest = recentlyForwarded.keys.firstOrNull()
            if (oldest != null) recentlyForwarded.remove(oldest)
        }
        return true
    }

    /** Forgets every fingerprint (call when mirroring is turned off). */
    fun reset() = recentlyForwarded.clear()

    private fun prune(now: Long) {
        val iterator = recentlyForwarded.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            // A clock jump backwards would otherwise strand entries forever.
            if (now - entry.value >= dedupeWindowMillis || entry.value > now) iterator.remove()
        }
    }

    /**
     * The fingerprint holds notification text, so it stays in memory only —
     * never logged, never persisted.
     */
    private fun fingerprint(notification: IncomingNotification): String =
        "${notification.packageName}\u0000${notification.title}\u0000${notification.text}"

    companion object {
        /** Long enough to swallow a chat app's repost storm, short enough that
         *  a genuinely repeated message still reaches the HUD. */
        const val DEFAULT_DEDUPE_WINDOW_MILLIS: Long = 10_000

        /** Bounded so a long-lived listener process cannot grow per notification. */
        const val DEFAULT_MAX_RECENT_ENTRIES = 64
    }
}
