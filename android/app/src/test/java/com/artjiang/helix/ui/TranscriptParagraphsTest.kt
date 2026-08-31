package com.artjiang.helix.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [paragraphsForTranscript] must turn one enormous transcript entry into
 * several short, readable paragraphs WITHOUT fabricating speaker turns —
 * the caller still renders every paragraph inside the same bubble. See
 * TranscriptParagraphs.kt for the full rationale.
 */
class TranscriptParagraphsTest {

    @Test
    fun `punctuated English produces multiple paragraphs`() {
        val sentence = "This is a reasonably long sentence about the quarterly roadmap. "
        val transcript = sentence.repeat(12).trim()

        val paragraphs = paragraphsForTranscript(transcript)

        assertTrue(
            "expected multiple paragraphs, got ${paragraphs.size}",
            paragraphs.size > 1,
        )
        assertNoLossOrDuplication(transcript, paragraphs)
    }

    @Test
    fun `long unpunctuated Chinese block also produces multiple paragraphs`() {
        // gpt-live-transcribe emits unpunctuated CJK; BreakIterator finds no
        // sentence boundaries in this string, so it comes back as ONE
        // "sentence" the size of the whole transcript. This is exactly the
        // path that must fall back to the character-budget slicer.
        val unit = "今天天气很好我们去公园散步看到很多人在跑步还有小孩在玩耽误了不少时间但是很开心"
        val transcript = unit.repeat(8)

        val paragraphs = paragraphsForTranscript(transcript)

        assertTrue(
            "expected multiple paragraphs for unpunctuated CJK, got ${paragraphs.size}",
            paragraphs.size > 1,
        )
        assertNoLossOrDuplication(transcript, paragraphs)
    }

    @Test
    fun `short text stays one paragraph`() {
        val transcript = "Hello there, quick check-in."

        val paragraphs = paragraphsForTranscript(transcript)

        assertEquals(1, paragraphs.size)
        assertNoLossOrDuplication(transcript, paragraphs)
    }

    @Test
    fun `blank input produces no paragraphs`() {
        assertEquals(emptyList<String>(), paragraphsForTranscript(""))
        assertEquals(emptyList<String>(), paragraphsForTranscript("   "))
    }

    /** Joining paragraphs and stripping whitespace must reproduce the input, stripped. */
    private fun assertNoLossOrDuplication(original: String, paragraphs: List<String>) {
        val rebuilt = paragraphs.joinToString("").filterNot { it.isWhitespace() }
        val expected = original.filterNot { it.isWhitespace() }
        assertEquals(expected, rebuilt)
    }
}
