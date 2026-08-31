package com.artjiang.helix.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingNotificationTest {

    private val presenter = RecordingNotificationPresenter()

    // MARK: - Content

    @Test
    fun `starting phase reports startup, not silence`() {
        val content = presenter.contentFor(RecordingPhase.STARTING, "")
        assertEquals(RecordingNotificationPresenter.TITLE, content.title)
        assertEquals(RecordingNotificationPresenter.STARTING_BODY, content.privateText)
    }

    @Test
    fun `starting phase ignores any transcript carried over`() {
        val content = presenter.contentFor(RecordingPhase.STARTING, "stale words")
        assertEquals(RecordingNotificationPresenter.STARTING_BODY, content.privateText)
    }

    @Test
    fun `active with no speech yet says listening`() {
        val content = presenter.contentFor(RecordingPhase.ACTIVE, "")
        assertEquals(RecordingNotificationPresenter.LISTENING_BODY, content.privateText)
    }

    @Test
    fun `blank-only transcript is treated as no speech`() {
        val content = presenter.contentFor(RecordingPhase.ACTIVE, "   \n ")
        assertEquals(RecordingNotificationPresenter.LISTENING_BODY, content.privateText)
    }

    @Test
    fun `active with speech shows the transcript`() {
        val content = presenter.contentFor(RecordingPhase.ACTIVE, "  what is the capital of France  ")
        assertEquals("what is the capital of France", content.privateText)
    }

    @Test
    fun `long transcript keeps the newest words and marks the trim`() {
        val text = (1..200).joinToString(" ") { "word$it" }
        val content = presenter.contentFor(RecordingPhase.ACTIVE, text)
        assertTrue(content.privateText.length <= RecordingNotificationPresenter.MAX_BODY_CHARS + 1)
        assertTrue(content.privateText.startsWith("…"))
        // The tail is what matters: the most recent word must survive.
        assertTrue(content.privateText.endsWith("word200"))
        // And it must not cut a word in half.
        assertFalse(content.privateText.contains("…ord"))
    }

    // MARK: - Privacy

    @Test
    fun `public text never carries transcript content in any phase`() {
        val secret = "my social security number is one two three"
        for (phase in listOf(RecordingPhase.STARTING, RecordingPhase.ACTIVE)) {
            val content = presenter.contentFor(phase, secret)
            assertEquals(RecordingNotificationPresenter.PUBLIC_BODY, content.publicText)
            assertFalse(content.publicText.contains("social"))
            assertFalse(content.publicText.contains("three"))
        }
    }

    @Test
    fun `public text still states that recording is active`() {
        val content = presenter.contentFor(RecordingPhase.ACTIVE, "anything")
        assertTrue(content.publicText.contains("Recording"))
        assertTrue(content.title.contains("recording"))
    }

    // MARK: - Throttle

    @Test
    fun `first update always posts`() {
        val content = presenter.contentFor(RecordingPhase.STARTING, "")
        assertTrue(presenter.shouldUpdate(content, 0L))
    }

    @Test
    fun `identical content is never re-posted however long it has been`() {
        val content = presenter.contentFor(RecordingPhase.ACTIVE, "hello")
        assertTrue(presenter.shouldUpdate(content, 0L))
        assertFalse(presenter.shouldUpdate(content, 60_000L))
    }

    @Test
    fun `changed content inside the interval is suppressed`() {
        val throttle = RecordingNotificationPresenter(minUpdateIntervalMillis = 1_500L)
        assertTrue(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "a"), 0L))
        assertFalse(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "ab"), 1_499L))
    }

    @Test
    fun `changed content once the interval elapses posts`() {
        val throttle = RecordingNotificationPresenter(minUpdateIntervalMillis = 1_500L)
        assertTrue(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "a"), 0L))
        assertTrue(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "ab"), 1_500L))
    }

    @Test
    fun `a suppressed update does not restart the interval`() {
        // Regression guard: if a rejected post advanced lastPostAt, a fast
        // token stream would push the deadline forever and the notification
        // would freeze on its first line.
        val throttle = RecordingNotificationPresenter(minUpdateIntervalMillis = 1_000L)
        assertTrue(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "a"), 0L))
        assertFalse(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "ab"), 400L))
        assertFalse(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "abc"), 800L))
        assertTrue(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "abcd"), 1_000L))
    }

    @Test
    fun `reset lets the next session post immediately`() {
        val throttle = RecordingNotificationPresenter(minUpdateIntervalMillis = 5_000L)
        val content = throttle.contentFor(RecordingPhase.ACTIVE, "a")
        assertTrue(throttle.shouldUpdate(content, 0L))
        assertFalse(throttle.shouldUpdate(throttle.contentFor(RecordingPhase.ACTIVE, "b"), 10L))
        throttle.reset()
        assertTrue(throttle.shouldUpdate(content, 20L))
    }

    // MARK: - Elapsed formatting

    @Test
    fun `elapsed formats under a minute`() {
        assertEquals("0:00", formatElapsed(0L))
        assertEquals("0:07", formatElapsed(7_400L))
        assertEquals("0:59", formatElapsed(59_999L))
    }

    @Test
    fun `elapsed formats minutes and rolls into hours`() {
        assertEquals("1:00", formatElapsed(60_000L))
        assertEquals("12:34", formatElapsed((12 * 60 + 34) * 1_000L))
        assertEquals("1:00:00", formatElapsed(3_600_000L))
        assertEquals("2:05:09", formatElapsed((2 * 3_600 + 5 * 60 + 9) * 1_000L))
    }

    @Test
    fun `negative elapsed clamps to zero rather than printing a minus`() {
        assertEquals("0:00", formatElapsed(-5_000L))
    }
}
