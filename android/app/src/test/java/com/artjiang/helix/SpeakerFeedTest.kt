package com.artjiang.helix

import com.artjiang.helix.core.TranscriptSegment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SpeakerFeedTest {

    @Test
    fun `an undiarized transcript segment defaults to unknown instead of the wearer`() {
        // OpenAI realtime and the on-device recognizer return no diarization,
        // so attributing the phone mic to the wearer would be a guess.
        val segment = TranscriptSegment(text = "hello", isFinal = true, timestampMillis = 1L)
        assertNull(segment.speaker)
        assertFalse(segment.isUser)
    }

    @Test
    fun `a transcript segment carries an explicit speaker when the source knows one`() {
        val segment = TranscriptSegment(
            text = "hello",
            isFinal = true,
            timestampMillis = 1L,
            speaker = "SPEAKER_1",
            isUser = false,
        )
        assertEquals("SPEAKER_1", segment.speaker)
        assertFalse(segment.isUser)
    }

    @Test
    fun `a feed entry carries speaker attribution`() {
        val entry = FeedEntry(
            id = 1,
            kind = FeedEntry.Kind.TRANSCRIPT,
            text = "hello",
            atMillis = 1L,
            speaker = "SPEAKER_2",
            isUser = false,
        )
        assertEquals("SPEAKER_2", entry.speaker)
        assertFalse(entry.isUser)
    }

    @Test
    fun `an explicitly attributed wearer remains the user`() {
        val segment = TranscriptSegment(
            text = "hello",
            isFinal = true,
            timestampMillis = 1L,
            speaker = "SPEAKER_0",
            isUser = true,
        )

        assertTrue(segment.isUser)
    }
}
