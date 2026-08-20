package com.artjiang.helix.ai

import com.artjiang.helix.core.QuestionCandidate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QuestionDetectorTest {

    private val detector = QuestionDetector()

    @Test
    fun `single word question with punctuation is detected at high confidence`() {
        // The Swift detector stripped the "?" while splitting sentences, so this
        // case fell through to the prefix list and was missed entirely.
        val results = detector.detectQuestions("Ready?")
        assertEquals(1, results.size)
        assertEquals("Ready?", results.first().text)
        assertEquals(QuestionDetector.PUNCTUATION_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `full width question mark is detected`() {
        val results = detector.detectQuestions("你叫什么名字？")
        assertEquals(1, results.size)
        assertEquals("你叫什么名字？", results.first().text)
        assertEquals(QuestionDetector.PUNCTUATION_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `chinese ma particle without punctuation is detected`() {
        val results = detector.detectQuestions("你今天有空吗")
        assertEquals(1, results.size)
        assertEquals(QuestionDetector.PREFIX_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `chinese ne particle is detected`() {
        assertTrue(detector.isQuestion("那你呢"))
    }

    @Test
    fun `english interrogative prefix without punctuation is lower confidence`() {
        val results = detector.detectQuestions("how does attention work")
        assertEquals(1, results.size)
        assertEquals(QuestionDetector.PREFIX_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `statements are not detected`() {
        assertTrue(detector.detectQuestions("The meeting starts at three.").isEmpty())
        assertTrue(detector.detectQuestions("我今天很忙。").isEmpty())
        assertTrue(detector.detectQuestions("That is a great result!").isEmpty())
    }

    @Test
    fun `statement containing an interrogative word mid sentence is not detected`() {
        // "how" appears but not as the leading word.
        assertTrue(detector.detectQuestions("I know how it works.").isEmpty())
    }

    @Test
    fun `terminal punctuation is preserved when splitting mixed sentences`() {
        val results = detector.detectQuestions("The demo went well. What did you think? We ship Friday.")
        assertEquals(1, results.size)
        assertEquals("What did you think?", results.first().text)
        assertEquals(QuestionDetector.PUNCTUATION_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `multiple questions in one transcript are all returned`() {
        val results = detector.detectQuestions("What is RAG? How does it help?")
        assertEquals(2, results.size)
        assertEquals("What is RAG?", results[0].text)
        assertEquals("How does it help?", results[1].text)
    }

    @Test
    fun `blank transcript yields nothing`() {
        assertTrue(detector.detectQuestions("   ").isEmpty())
        assertTrue(detector.detectQuestions("").isEmpty())
    }

    @Test
    fun `quoted question still counts`() {
        assertTrue(detector.isQuestion("\"Ready?\""))
    }
}

class DuplicateQuestionSuppressorTest {

    private fun candidate(text: String) = QuestionCandidate(text, 0.95)

    @Test
    fun `identical questions are suppressed`() {
        val suppressor = DuplicateQuestionSuppressor()
        val results = suppressor.uniqueQuestions(
            listOf(candidate("What is RAG?"), candidate("What is RAG?")),
        )
        assertEquals(1, results.size)
    }

    @Test
    fun `punctuation and casing differences normalize to the same key`() {
        val suppressor = DuplicateQuestionSuppressor()
        assertTrue(suppressor.markIfNew("What is RAG?"))
        assertFalse(suppressor.markIfNew("what is rag"))
        assertFalse(suppressor.markIfNew("  What   is RAG!! "))
    }

    @Test
    fun `distinct chinese questions are not collapsed`() {
        // The Swift normalizer stripped every non-ASCII character, so both of
        // these produced an empty key and the second was wrongly suppressed.
        val suppressor = DuplicateQuestionSuppressor()
        assertTrue(suppressor.markIfNew("你叫什么名字？"))
        assertTrue(suppressor.markIfNew("你今年多大？"))
        assertEquals(2, suppressor.uniqueQuestions(
            listOf(candidate("我们几点开会？"), candidate("会议在哪里？")),
        ).size)
    }

    @Test
    fun `identical chinese questions are still suppressed`() {
        val suppressor = DuplicateQuestionSuppressor()
        assertTrue(suppressor.markIfNew("你叫什么名字？"))
        assertFalse(suppressor.markIfNew("你叫什么名字?"))
        assertFalse(suppressor.markIfNew(" 你叫什么名字 "))
    }

    @Test
    fun `reset clears seen state`() {
        val suppressor = DuplicateQuestionSuppressor()
        assertTrue(suppressor.markIfNew("What is RAG?"))
        assertFalse(suppressor.markIfNew("What is RAG?"))
        suppressor.reset()
        assertTrue(suppressor.markIfNew("What is RAG?"))
    }

    @Test
    fun `punctuation only question is never marked new`() {
        val suppressor = DuplicateQuestionSuppressor()
        assertFalse(suppressor.markIfNew("???"))
    }

    @Test
    fun `hasSeen reflects recorded questions`() {
        val suppressor = DuplicateQuestionSuppressor()
        assertFalse(suppressor.hasSeen("你叫什么名字？"))
        suppressor.markIfNew("你叫什么名字？")
        assertTrue(suppressor.hasSeen("你叫什么名字？"))
    }
}
