package com.artjiang.helix.ai

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LlmQuestionDetectorTest {

    /** Records whether/how many times the fake classifier was invoked. */
    private class FakeClassifier(private val response: (String) -> String) {
        var callCount = 0
            private set
        var lastPrompt: String? = null

        suspend fun classify(text: String): String {
            callCount++
            lastPrompt = text
            return response(text)
        }
    }

    // --- The four realistic Chinese questions from the bug report ---
    // Each is either caught by the widened heuristic pre-filter directly, or
    // requires the LLM path (a fake standing in for the FAST-tier model).

    @Test
    fun `you-neng question is detected via the LLM path`() = runTest {
        // "你能帮我看一下这个报错" (can you help me look at this error) has no "?",
        // no tail particle, no listed interrogative, and no A-not-A phrase —
        // the heuristic alone cannot catch it. This is exactly the case the
        // LLM detector exists for.
        val transcript = "你能帮我看一下这个报错"
        val fake = FakeClassifier { """["你能帮我看一下这个报错"]""" }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions(transcript)

        assertEquals(1, fake.callCount)
        assertTrue(results.any { it.text == transcript })
    }

    @Test
    fun `you-mei-you A-not-A question is detected by the widened heuristic alone`() = runTest {
        // "有没有别的办法" (is there another way) — A-not-A construction, the
        // single most common spoken Chinese interrogative form and previously
        // entirely absent from QuestionDetector's rules.
        val transcript = "有没有别的办法"
        val fake = FakeClassifier { LlmQuestionDetector.NONE_MARKER }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions(transcript)

        assertTrue(results.any { it.text == transcript })
    }

    @Test
    fun `ji-lou question is detected by the widened heuristic alone`() = runTest {
        // "会议室在几楼" (what floor is the meeting room on) — only "几点" was
        // previously listed, so "几楼" (a different, equally common measure
        // word) was missed outright.
        val transcript = "会议室在几楼"
        val fake = FakeClassifier { LlmQuestionDetector.NONE_MARKER }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions(transcript)

        assertTrue(results.any { it.text == transcript })
    }

    @Test
    fun `mid-string ma particle question is detected by the widened heuristic alone`() = runTest {
        // "这个方案可行吗我们下周定" — the "吗" particle sits MID-STRING (a
        // trailing clause is tacked on after the question), not at the end,
        // so the old strict endsWith check missed it.
        val transcript = "这个方案可行吗我们下周定"
        val fake = FakeClassifier { LlmQuestionDetector.NONE_MARKER }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions(transcript)

        assertTrue(results.any { it.text == transcript })
    }

    // --- Cost control ---

    @Test
    fun `confident heuristic hit skips the LLM call entirely`() = runTest {
        val fake = FakeClassifier { error("classify must not be called") }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("Ready?")

        assertEquals(0, fake.callCount)
        assertEquals(1, results.size)
        assertEquals("Ready?", results.first().text)
    }

    @Test
    fun `explicit question in a mixed utterance does not hide a later implicit question`() = runTest {
        val fake = FakeClassifier { """["I wonder who approved it"]""" }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("What changed? I wonder who approved it")

        assertEquals(
            "a confident hit only skips classification for a genuinely single-question utterance",
            1,
            fake.callCount,
        )
        assertEquals(
            setOf("What changed?", "I wonder who approved it"),
            results.map { it.text }.toSet(),
        )
    }

    @Test
    fun `merged questions stay in spoken order instead of confidence order`() = runTest {
        val transcript = "Can you explain RAG. What are its limitations?"
        val detector = LlmQuestionDetector(
            classify = { """["Can you explain RAG."]""" },
        )

        val results = detector.detectQuestions(transcript)

        assertEquals(
            "a later punctuation hit must not jump ahead of an earlier classified question",
            listOf("Can you explain RAG.", "What are its limitations?"),
            results.map { it.text },
        )
        assertTrue(results.first().confidence < results.last().confidence)
    }

    @Test
    fun `low-confidence heuristic hit does NOT skip the LLM call`() = runTest {
        // "有没有别的办法" only reaches A_NOT_A_CONFIDENCE (0.60), below the
        // default skip threshold (PUNCTUATION_CONFIDENCE, 0.95) — the LLM is
        // still asked to confirm/extend it.
        val fake = FakeClassifier { LlmQuestionDetector.NONE_MARKER }
        val detector = LlmQuestionDetector(classify = fake::classify)

        detector.detectQuestions("有没有别的办法")

        assertEquals(1, fake.callCount)
    }

    @Test
    fun `network failure falls back to the heuristic instead of returning nothing`() = runTest {
        val fake = FakeClassifier { throw java.io.IOException("simulated network failure") }
        val detector = LlmQuestionDetector(classify = fake::classify)

        // "有没有别的办法" is caught by the heuristic alone (A-not-A), so even
        // though the LLM call is attempted and fails, the result must not be
        // empty.
        val results = detector.detectQuestions("有没有别的办法")

        assertEquals(1, fake.callCount)
        assertFalse("a network failure must not make detection go silent", results.isEmpty())
        assertTrue(results.any { it.text == "有没有别的办法" })
    }

    @Test
    fun `network failure with nothing for the heuristic to find returns empty, not a crash`() = runTest {
        val fake = FakeClassifier { throw java.io.IOException("simulated network failure") }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("你能帮我看一下这个报错")

        assertEquals(1, fake.callCount)
        assertTrue(results.isEmpty())
    }

    @Test
    fun `malformed classifier response falls back to the heuristic result`() = runTest {
        val fake = FakeClassifier { "" }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("有没有别的办法")

        assertTrue(results.any { it.text == "有没有别的办法" })
    }

    @Test
    fun `blank transcript never calls the classifier`() = runTest {
        val fake = FakeClassifier { error("classify must not be called") }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("   ")

        assertEquals(0, fake.callCount)
        assertTrue(results.isEmpty())
    }

    @Test
    fun `all questions found by the LLM are returned, not just the first`() = runTest {
        val fake = FakeClassifier { """["第一个问题","第二个问题"]""" }
        val detector = LlmQuestionDetector(classify = fake::classify)

        val results = detector.detectQuestions("第一个问题 第二个问题")

        assertEquals(2, results.size)
        assertTrue(results.any { it.text == "第一个问题" })
        assertTrue(results.any { it.text == "第二个问题" })
    }

    @Test
    fun `classifier prose headers numbering and malformed JSON produce no candidates`() = runTest {
        val responses = listOf(
            "Here are the questions:\n1. Please review this",
            """{"questions":["Please review this"]}""",
            """["1. Please review this"]""",
            "not-json",
        )

        for (response in responses) {
            val detector = LlmQuestionDetector(classify = { response })
            assertTrue(response, detector.detectQuestions("Please review this").isEmpty())
        }
    }

    @Test
    fun `strict empty JSON array represents a true no-question result`() = runTest {
        val detector = LlmQuestionDetector(classify = { "[]" })

        assertTrue(detector.detectQuestions("The launch starts Friday.").isEmpty())
    }

    @Test
    fun `sensitivity changes acceptance instead of only changing the skip threshold`() = runTest {
        val precise = LlmQuestionDetector(
            classify = { LlmQuestionDetector.NONE_MARKER },
            sensitivity = { QuestionSensitivity.PRECISE },
        )
        val balanced = LlmQuestionDetector(
            classify = { LlmQuestionDetector.NONE_MARKER },
            sensitivity = { QuestionSensitivity.BALANCED },
        )

        // Spoken Chinese A-not-A is a likely question but lacks punctuation.
        // Precise requires an explicit/direct confirmation; Balanced retains
        // the strong multilingual heuristic even if the model returns NONE.
        assertTrue(precise.detectQuestions("有没有别的办法").isEmpty())
        assertEquals("有没有别的办法", balanced.detectQuestions("有没有别的办法").single().text)
    }

    @Test
    fun `classifier prompt names the level and includes multilingual examples`() {
        val prompt = LlmQuestionDetector.classifierPrompt(
            transcript = "live words",
            sensitivity = QuestionSensitivity.HIGH,
        )

        assertTrue(prompt.contains("High sensitivity"))
        assertTrue(prompt.contains("Can you"))
        assertTrue(prompt.contains("你能"))
        assertTrue(prompt.contains("¿"))
        assertTrue(prompt.contains("Speech: live words"))
        assertTrue(prompt.contains("JSON array"))
    }
}
