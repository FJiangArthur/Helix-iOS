// Pure content/throttle layer for the persistent "recording" notification.
//
// Deliberately free of android.* types, matching NotificationMirrorFilter: every
// rule below is JVM-testable and RecordingService stays a thin adapter that
// converts this data into a NotificationCompat.Builder.
//
// PRIVACY: the transcript text this class carries is the user's (and nearby
// speakers') live speech. It is never logged — not here, not in the service.
// [RecordingContent.publicText] exists so the lock screen can be told that a
// recording is running without spilling what was said; see the doc on
// [RecordingContent] for the full reasoning.
package com.artjiang.helix.service

/** What the session is currently doing, in the order it progresses. */
enum class RecordingPhase {
    /** Service is up, capture has not reported itself listening yet. */
    STARTING,

    /** Capture is live. */
    ACTIVE,

    /** Session ended (or never began); the notification should be torn down. */
    STOPPED,
}

/**
 * The rendered text of one notification update.
 *
 * Two bodies, deliberately:
 *
 *  - [privateText] is the full detail — the latest transcript line. It renders
 *    only where the device is unlocked, because the notification is posted with
 *    VISIBILITY_PRIVATE.
 *  - [publicText] is what a **locked** screen shows. It states that Helix is
 *    recording and nothing more.
 *
 * The conservative split is the point. This notification is, by design, always
 * on screen while recording, so on a locked phone lying on a table it would
 * otherwise broadcast a live transcript of the room to anyone walking past —
 * including speech from people who never consented to Helix at all. Elapsed
 * time and "recording" are what the user needs from across the room (the whole
 * reason for the indicator); the words themselves are only ever worth showing
 * to someone who can already unlock the phone and open the app.
 */
data class RecordingContent(
    val title: String,
    val privateText: String,
    val publicText: String,
)

/**
 * Builds notification text and decides when an update is worth posting.
 *
 * Stateful only in the throttle: [shouldUpdate] remembers the last accepted
 * content and timestamp. Content building itself ([contentFor]) is pure.
 *
 * @param minUpdateIntervalMillis floor between two posted updates. Notification
 *        posts are relatively expensive and rate-limited by the system, and
 *        partial transcripts arrive per-token, so posting every change would
 *        both burn battery and get silently dropped by NotificationManager.
 */
class RecordingNotificationPresenter(
    private val minUpdateIntervalMillis: Long = DEFAULT_MIN_UPDATE_INTERVAL_MILLIS,
) {

    private var lastContent: RecordingContent? = null
    private var lastPostAtMillis: Long = Long.MIN_VALUE

    /**
     * The text for the current state.
     *
     * @param phase session phase.
     * @param transcript most recent transcript text; blank until speech lands.
     */
    fun contentFor(phase: RecordingPhase, transcript: String): RecordingContent {
        val trimmed = transcript.trim()
        val body = when {
            phase == RecordingPhase.STARTING -> STARTING_BODY
            trimmed.isEmpty() -> LISTENING_BODY
            else -> trimmed.takeLastWords(MAX_BODY_CHARS)
        }
        return RecordingContent(
            title = TITLE,
            privateText = body,
            publicText = PUBLIC_BODY,
        )
    }

    /**
     * True when [content] should actually be posted at [nowMillis].
     *
     * Accepts when either the content changed **and** the interval has elapsed,
     * or this is the first post. Unchanged content is never re-posted, however
     * long it has been: a redundant post costs the same as a real one and the
     * chronometer keeps ticking on its own without any help from us.
     */
    fun shouldUpdate(content: RecordingContent, nowMillis: Long): Boolean {
        val previous = lastContent
        if (previous == content) return false
        if (previous != null && nowMillis - lastPostAtMillis < minUpdateIntervalMillis) return false
        lastContent = content
        lastPostAtMillis = nowMillis
        return true
    }

    /** Forgets throttle state so the next session starts with an immediate post. */
    fun reset() {
        lastContent = null
        lastPostAtMillis = Long.MIN_VALUE
    }

    /**
     * Keeps the tail of [text] within [limit] characters, cut at a word
     * boundary. The newest speech is the interesting end, so this trims the
     * front — the opposite of the usual ellipsis.
     */
    private fun String.takeLastWords(limit: Int): String {
        if (length <= limit) return this
        val tail = substring(length - limit)
        val boundary = tail.indexOf(' ')
        val clean = if (boundary in 0 until limit - 1) tail.substring(boundary + 1) else tail
        return "…$clean"
    }

    companion object {
        const val DEFAULT_MIN_UPDATE_INTERVAL_MILLIS = 1_500L

        /** Cap so the expanded notification stays a glance, not a wall of text. */
        const val MAX_BODY_CHARS = 180

        const val TITLE = "Helix is recording"
        const val STARTING_BODY = "Starting…"
        const val LISTENING_BODY = "Listening — no speech yet."

        /** Lock-screen body. States the fact, never the content. */
        const val PUBLIC_BODY = "Recording in progress."
    }
}

/** Formats [millis] as m:ss, or h:mm:ss past an hour. Used by tests and any UI. */
fun formatElapsed(millis: Long): String {
    val totalSeconds = (if (millis < 0) 0 else millis) / 1_000
    val seconds = totalSeconds % 60
    val minutes = (totalSeconds / 60) % 60
    val hours = totalSeconds / 3_600
    return if (hours > 0) {
        "%d:%02d:%02d".format(hours, minutes, seconds)
    } else {
        "%d:%02d".format(minutes, seconds)
    }
}
