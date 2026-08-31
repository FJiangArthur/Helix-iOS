package com.artjiang.helix.ai

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnsweringPhaseTrackerTest {

    @Test
    fun `thinking is false before a turn starts`() {
        val tracker = AnsweringPhaseTracker()
        assertFalse(tracker.isThinking)
    }

    @Test
    fun `thinking becomes true once answering starts`() {
        val tracker = AnsweringPhaseTracker()
        tracker.start()
        assertTrue("thinking must be true once a turn is armed", tracker.isThinking)
    }

    @Test
    fun `thinking becomes false once the first delta arrives`() {
        val tracker = AnsweringPhaseTracker()
        tracker.start()
        tracker.onDelta()
        assertFalse("the first token must end the thinking phase", tracker.isThinking)
    }

    @Test
    fun `later deltas keep thinking false`() {
        val tracker = AnsweringPhaseTracker()
        tracker.start()
        tracker.onDelta()
        tracker.onDelta()
        tracker.onDelta()
        assertFalse(tracker.isThinking)
    }

    @Test
    fun `end clears thinking even with no delta, for a suppressed or errored turn`() {
        val tracker = AnsweringPhaseTracker()
        tracker.start()
        tracker.end()
        assertFalse("a turn that never streams must not leave thinking stuck true", tracker.isThinking)
    }

    @Test
    fun `a fresh start after end begins thinking again`() {
        val tracker = AnsweringPhaseTracker()
        tracker.start()
        tracker.onDelta()
        tracker.end()

        tracker.start()
        assertTrue(tracker.isThinking)
    }
}
