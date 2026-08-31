package com.artjiang.helix

import com.artjiang.helix.core.QuestionCandidate
import org.junit.Assert.assertEquals
import org.junit.Test

class CandidateStreamPreviewTest {

    @Test
    fun `concurrent question chunks never interleave in the shared preview`() {
        val preview = StringBuilder()
        val first = QuestionCandidate("What is RAG?", 0.95)
        val second = QuestionCandidate("How does it help?", 0.95)
        val router = CandidateStreamPreview(preview::append)

        router.onStarted(first)
        router.onStarted(second)
        router.onDelta(first, "First ")
        router.onDelta(second, "SECOND-GARBAGE ")
        router.onDelta(first, "answer.")
        router.onDelta(second, "MORE-GARBAGE")

        assertEquals("First answer.", preview.toString())
    }
}
