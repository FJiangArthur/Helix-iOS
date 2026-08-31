package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HudSessionNoticesTest {

    @Test
    fun theReminderCadenceIsTenMinutes() {
        assertEquals(10 * 60 * 1000L, HudSessionNotices.REMINDER_INTERVAL_MILLIS)
    }

    @Test
    fun elapsedRendersCompactlyForTheFiveLineHud() {
        assertEquals("0 min", HudSessionNotices.formatElapsed(0))
        assertEquals("10 min", HudSessionNotices.formatElapsed(10 * 60_000L))
        assertEquals("59 min", HudSessionNotices.formatElapsed(59 * 60_000L))
        assertEquals("1h 0m", HudSessionNotices.formatElapsed(60 * 60_000L))
        assertEquals("1h 20m", HudSessionNotices.formatElapsed(80 * 60_000L))
        assertEquals("8h 0m", HudSessionNotices.formatElapsed(8 * 60 * 60_000L))
    }

    @Test
    fun elapsedNeverRendersNegativeTime() {
        // A clock that steps backwards (NTP correction) must not print "-1 min".
        assertEquals("0 min", HudSessionNotices.formatElapsed(-5_000))
    }

    @Test
    fun theReminderNamesTheElapsedSession() {
        val text = HudSessionNotices.reminder(10 * 60_000L)
        assertTrue("the reminder must say it is still transcribing: $text",
            text.contains("Still transcribing"))
        assertTrue("the reminder must carry elapsed time: $text", text.contains("10 min"))
    }

    @Test
    fun startAndStopNoticesAreDistinguishable() {
        assertEquals("Transcription started", HudSessionNotices.SESSION_START)
        assertEquals("Transcription stopped", HudSessionNotices.SESSION_STOP)
    }

    /**
     * The HUD is 5 lines at 488px/21pt. A notice that paginates would push the
     * wearer into a multi-page banner for what should be a glanceable line.
     */
    @Test
    fun everyNoticeFitsOnASinglePage() {
        val paginator = HudPaginator()
        val notices = listOf(
            HudSessionNotices.SESSION_START,
            HudSessionNotices.SESSION_STOP,
            HudSessionNotices.reminder(8 * 60 * 60_000L),
        )
        notices.forEach { notice ->
            assertEquals("'$notice' must fit one HUD page", 1, paginator.pages(notice).size)
        }
    }
}
