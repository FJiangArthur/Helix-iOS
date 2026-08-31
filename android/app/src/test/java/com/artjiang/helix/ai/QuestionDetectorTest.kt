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

    // --- Widened Chinese heuristics: A-not-A, additional interrogatives, and
    // a mid-string (not just endsWith) particle check. Each of these is one
    // of the four realistic spoken-Chinese questions from the bug report. ---

    @Test
    fun `a-not-a construction is detected without any particle or punctuation`() {
        // "有没有别的办法" (is there another way) — the single most common
        // spoken Chinese interrogative form, previously entirely absent from
        // the rules: no "?", no tail particle, no listed interrogative word.
        val results = detector.detectQuestions("有没有别的办法")
        assertEquals(1, results.size)
        assertEquals("有没有别的办法", results.first().text)
        assertEquals(QuestionDetector.A_NOT_A_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `other A-not-A phrases are also detected`() {
        assertTrue(detector.isQuestion("你是不是忘了"))
        assertTrue(detector.isQuestion("你能不能帮我"))
        assertTrue(detector.isQuestion("这个可不可以改一下"))
        assertTrue(detector.isQuestion("你对不对啊"))
    }

    @Test
    fun `ji-lou is detected even though only ji-dian was previously listed`() {
        // "会议室在几楼" (what floor is the meeting room on) — "几点" (what
        // time) was listed but "几楼" was not, so a structurally identical
        // question about floor number instead of time was missed.
        val results = detector.detectQuestions("会议室在几楼")
        assertEquals(1, results.size)
        assertEquals(QuestionDetector.PREFIX_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `tail particle mid-string is detected, not just at the end`() {
        // "这个方案可行吗我们下周定" — "吗" sits mid-string because a trailing
        // clause is tacked on after the question; the old strict endsWith
        // check missed every case shaped like this.
        val results = detector.detectQuestions("这个方案可行吗我们下周定")
        assertEquals(1, results.size)
        assertEquals(QuestionDetector.PREFIX_CONFIDENCE, results.first().confidence, 0.0001)
    }

    @Test
    fun `a-not-a confidence is lower than the punctuation and prefix confidences`() {
        assertTrue(QuestionDetector.A_NOT_A_CONFIDENCE < QuestionDetector.PREFIX_CONFIDENCE)
        assertTrue(QuestionDetector.PREFIX_CONFIDENCE < QuestionDetector.PUNCTUATION_CONFIDENCE)
    }

    @Test
    fun `plain statement with none of the new patterns is still not detected`() {
        assertTrue(detector.detectQuestions("我们决定周五发布这个版本。").isEmpty())
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

    @Test
    fun `a question repeats once the suppression window has passed`() {
        var now = 0L
        val suppressor = DuplicateQuestionSuppressor(clock = { now })

        assertTrue("first ask is new", suppressor.markIfNew("What is the deadline?"))
        now = 60_000L
        assertFalse("still suppressed inside the window", suppressor.markIfNew("What is the deadline?"))

        now = DuplicateQuestionSuppressor.DEFAULT_WINDOW_MILLIS + 1
        assertTrue(
            "the same question much later is a NEW question, not a duplicate",
            suppressor.markIfNew("What is the deadline?"),
        )
    }

    @Test
    fun `the suppressor is bounded so a long session cannot grow it without limit`() {
        var now = 0L
        val suppressor = DuplicateQuestionSuppressor(clock = { now })
        repeat(DuplicateQuestionSuppressor.DEFAULT_MAX_ENTRIES + 50) { i ->
            now += 1
            suppressor.markIfNew("question number $i")
        }
        assertFalse(
            "the oldest key must have been evicted by the cap",
            suppressor.hasSeen("question number 0"),
        )
        assertTrue(
            "the most recent key must still suppress",
            suppressor.hasSeen(
                "question number ${DuplicateQuestionSuppressor.DEFAULT_MAX_ENTRIES + 49}",
            ),
        )
    }
}
