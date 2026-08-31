package com.artjiang.helix.g1

/**
 * Copy and cadence for the HUD notices that bracket a transcription session.
 *
 * Pure so the wording and the reminder schedule are unit-testable without BLE
 * or a real clock. The bridge owns the timer; this owns "what to say and when".
 *
 * The wearer cannot see a phone-side recording indicator while wearing the
 * glasses, so the HUD is the only honest signal that the microphone is live.
 * That makes the recurring reminder a privacy affordance, not a nicety: a
 * session left running is otherwise invisible to the person wearing it.
 */
object HudSessionNotices {
    /** Shown once when a session starts, from either trigger. */
    const val SESSION_START = "Transcription started"

    /**
     * How often the "still listening" reminder repeats. 10 minutes matches the
     * requested cadence: frequent enough that a forgotten session is caught,
     * rare enough that it does not interrupt a conversation.
     */
    const val REMINDER_INTERVAL_MILLIS: Long = 10 * 60 * 1000

    /** Shown when a session ends, so the wearer knows the mic is closed. */
    const val SESSION_STOP = "Transcription stopped"

    /**
     * Reminder copy for a session that has been running [elapsedMillis].
     *
     * The elapsed time is included because "still recording" alone does not
     * tell the wearer whether they started this two minutes or two hours ago —
     * which is exactly the question a forgotten session raises.
     */
    fun reminder(elapsedMillis: Long): String =
        "Still transcribing · ${formatElapsed(elapsedMillis)}"

    /**
     * Compact elapsed rendering: "10 min" under an hour, "1h 20m" beyond it.
     * The HUD is 5 lines of 488px, so brevity matters more than precision.
     */
    internal fun formatElapsed(elapsedMillis: Long): String {
        val totalMinutes = (elapsedMillis / 60_000).coerceAtLeast(0)
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return if (hours > 0) "${hours}h ${minutes}m" else "$totalMinutes min"
    }
}
