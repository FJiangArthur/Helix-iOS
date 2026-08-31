package com.artjiang.helix

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class QuestionFeedAttributionTest {

    @Test
    fun `missing source attribution stays unknown instead of becoming the wearer`() {
        val placement = questionFeedPlacement(QuestionFeedOrigin.TRANSCRIPT, null)

        assertEquals(true, placement.shouldAppend)
        assertEquals(null, placement.attribution.speaker)
        assertFalse(placement.attribution.isUser)
    }

    @Test
    fun `typed manual question is appended as the wearer`() {
        val placement = questionFeedPlacement(QuestionFeedOrigin.TYPED_USER, null)

        assertEquals(true, placement.shouldAppend)
        assertEquals(null, placement.attribution.speaker)
        assertEquals(true, placement.attribution.isUser)
    }

    @Test
    fun `think deeper does not duplicate the existing question row`() {
        val placement = questionFeedPlacement(QuestionFeedOrigin.EXISTING_FEED, null)

        assertFalse(placement.shouldAppend)
    }

    @Test
    fun `substring question keeps diarized participant attribution when promotion cannot apply`() {
        val participantTranscript = FeedEntry(
            id = 7,
            kind = FeedEntry.Kind.TRANSCRIPT,
            text = "Some context. What changed? Who approved it?",
            atMillis = 1_000,
            speaker = "SPEAKER_02",
            isUser = false,
        )

        val attribution = questionFeedAttribution(participantTranscript)

        assertEquals("SPEAKER_02", attribution.speaker)
        assertFalse(attribution.isUser)
    }
}
