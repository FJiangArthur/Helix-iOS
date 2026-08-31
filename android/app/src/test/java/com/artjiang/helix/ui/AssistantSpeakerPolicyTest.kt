package com.artjiang.helix.ui

import com.artjiang.helix.FeedEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSpeakerPolicyTest {

    private fun transcript(
        speaker: String? = null,
        isUser: Boolean = false,
    ) = FeedEntry(
        id = 1,
        kind = FeedEntry.Kind.TRANSCRIPT,
        text = "hello",
        atMillis = 1,
        speaker = speaker,
        isUser = isUser,
    )

    @Test
    fun `undiarized speech renders as unknown speaker on the non-user side`() {
        val presentation = speakerBubblePresentation(transcript())

        assertEquals("Unknown speaker", presentation.author)
        assertFalse(presentation.isWearer)
    }

    @Test
    fun `source-provided wearer attribution still renders as You`() {
        val presentation = speakerBubblePresentation(
            transcript(speaker = "SPEAKER_00", isUser = true),
        )

        assertEquals("You", presentation.author)
        assertTrue(presentation.isWearer)
    }

    @Test
    fun `named participants and later mark-as-me attribution remain representable`() {
        val participant = transcript(speaker = "Alex")
        assertEquals("Alex", speakerBubblePresentation(participant).author)

        val markedAsMe = participant.copy(speaker = "You", isUser = true)
        assertEquals("You", speakerBubblePresentation(markedAsMe).author)
        assertTrue(speakerBubblePresentation(markedAsMe).isWearer)
    }
}
