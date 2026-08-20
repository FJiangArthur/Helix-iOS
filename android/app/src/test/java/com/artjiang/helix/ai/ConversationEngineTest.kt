package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationEngineTest {

    /** Records what the engine actually asked the provider for. */
    private class RecordingProvider(
        override val kind: ProviderKind = ProviderKind.DETERMINISTIC,
        override val model: String = "recording",
        private val error: Throwable? = null,
    ) : AnswerProvider {
        val requests = mutableListOf<AnswerRequest>()

        override suspend fun answer(request: AnswerRequest): AnswerResponse {
            requests += request
            error?.let { throw it }
            return AnswerResponse("answer for ${request.question}", kind, model)
        }
    }

    @Test
    fun `detected question is answered end to end`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())

        val turn = engine.processLiveTranscript("What is an LLM?")

        assertNotNull(turn.question)
        assertEquals("What is an LLM?", turn.question!!.text)
        assertEquals(QuestionDetector.PUNCTUATION_CONFIDENCE, turn.question!!.confidence, 0.0001)
        assertNotNull(turn.answer)
        assertEquals(
            "An LLM uses transformer attention to predict useful next tokens from context.",
            turn.answer!!.text,
        )
        assertNull(turn.suppressed)
        assertEquals(turn.answer, engine.activeAnswer)
    }

    @Test
    fun `statement produces no question and no answer`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())
        val turn = engine.processLiveTranscript("The meeting starts at three.")

        assertNull(turn.question)
        assertNull(turn.answer)
        assertNull(turn.suppressed)
    }

    @Test
    fun `duplicate question is suppressed on the second pass`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        val first = engine.processLiveTranscript("What is RAG?")
        val second = engine.processLiveTranscript("What is RAG?")

        assertNotNull(first.answer)
        assertNull(second.answer)
        assertEquals(SuppressionReason.DUPLICATE, second.suppressed)
        assertNotNull("the question is still surfaced", second.question)
        assertEquals("provider called once", 1, provider.requests.size)
    }

    @Test
    fun `distinct chinese questions are both answered`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        val first = engine.processLiveTranscript("你叫什么名字？")
        val second = engine.processLiveTranscript("你今年多大？")

        assertNotNull(first.answer)
        assertNotNull("CJK dedup must not collapse distinct questions", second.answer)
        assertEquals(2, provider.requests.size)
    }

    @Test
    fun `auto answer off surfaces the question without answering`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(autoAnswer = false),
            provider = provider,
        )

        val turn = engine.processLiveTranscript("What is RAG?")

        assertNotNull(turn.question)
        assertNull(turn.answer)
        assertEquals(SuppressionReason.AUTO_ANSWER_DISABLED, turn.suppressed)
        assertTrue(provider.requests.isEmpty())
        assertNull(engine.activeAnswer)
    }

    @Test
    fun `auto detect off skips detection entirely`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(autoDetectQuestions = false),
            provider = provider,
        )

        val turn = engine.processLiveTranscript("What is RAG?")

        assertNull(turn.question)
        assertNull(turn.answer)
        assertEquals(SuppressionReason.DETECTION_DISABLED, turn.suppressed)
        assertTrue(provider.requests.isEmpty())
    }

    @Test
    fun `text question is answered even with both gates off`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(autoDetectQuestions = false, autoAnswer = false),
            provider = provider,
        )

        val turn = engine.answerTextQuestion("Summarize the roadmap")

        assertNotNull(turn.answer)
        assertNull(turn.suppressed)
        assertEquals(1, provider.requests.size)
        assertEquals("Summarize the roadmap", provider.requests.first().question)
    }

    @Test
    fun `text question bypasses detection for a statement shaped prompt`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())
        val turn = engine.answerTextQuestion("Tell me about transformers.")
        assertNotNull(turn.answer)
    }

    @Test
    fun `session memory is fed into the answer request and capped`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            provider = provider,
            transcriptWindowSize = 2,
        )

        engine.processLiveTranscript("We shipped the beta on Monday.")
        engine.processLiveTranscript("The rollout covered every region.")
        engine.processLiveTranscript("What happened on Monday?")

        val context = provider.requests.single().conversationContext
        // Context is the history *before* the current utterance: the question
        // itself must not be duplicated into it, and the 2-line window holds
        // the two prior transcripts.
        assertEquals(2, context.lines().size)
        assertFalse(context.contains("What happened on Monday?"))
        assertTrue(context.contains("Heard: The rollout covered every region."))
        assertTrue(context.contains("Heard: We shipped the beta on Monday."))
    }

    @Test
    fun `answer is written back into session memory`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())
        engine.processLiveTranscript("What is an LLM?")

        val context = engine.transcriptContext()
        assertTrue(context.contains("Q: What is an LLM?"))
        assertTrue(context.contains("A: An LLM uses transformer attention"))
    }

    @Test
    fun `settings mode and sentence budget reach the request`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        engine.updateSettings(
            HelixSettings(mode = ConversationMode.INTERVIEW, maxResponseSentences = 5),
        )
        engine.processLiveTranscript("Why should we hire you?")

        val request = provider.requests.single()
        assertEquals(ConversationMode.INTERVIEW, request.mode)
        assertEquals(5, request.maxResponseSentences)
    }

    @Test
    fun `knowledge context is attached to the request`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            provider = provider,
            knowledgeProvider = { listOf("Helix runs on G1 glasses") },
        )

        engine.processLiveTranscript("What hardware do we support?")

        assertEquals(listOf("Helix runs on G1 glasses"), provider.requests.single().knowledgeContext)
    }

    @Test
    fun `a new transcript clears the previous active answer`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())

        engine.processLiveTranscript("What is an LLM?")
        assertNotNull(engine.activeAnswer)

        // A plain statement produces no answer — the stale one must not survive.
        engine.processLiveTranscript("That makes sense.")
        assertNull(engine.activeAnswer)
    }

    @Test
    fun `provider failure is captured as a suppressed turn`() = runTest {
        val engine = ConversationEngine(
            provider = RecordingProvider(error = ProviderHttpException(ProviderKind.OPENAI, 500, "boom")),
        )

        val turn = engine.processLiveTranscript("What is RAG?")

        assertNull(turn.answer)
        assertEquals(SuppressionReason.PROVIDER_ERROR, turn.suppressed)
        assertTrue(turn.error is ProviderHttpException)
        assertNull(engine.activeAnswer)
        assertTrue(engine.eventLog().any { it is ConversationEvent.Failed })
    }

    @Test
    fun `event log records the pipeline in order with timestamps`() = runTest {
        var now = 1_000L
        val engine = ConversationEngine(
            provider = DeterministicProvider(),
            clock = { now += 10; now },
        )

        engine.processLiveTranscript("What is an LLM?")

        val log = engine.eventLog()
        assertTrue(log[0] is ConversationEvent.TranscriptReceived)
        assertTrue(log.any { it is ConversationEvent.QuestionDetected })
        assertTrue(log.any { it is ConversationEvent.AnswerStarted })
        val completed = log.filterIsInstance<ConversationEvent.AnswerCompleted>().single()
        assertTrue("latency is measured from the real clock", completed.latencyMillis > 0)
        assertTrue(log.all { it.timestampMillis >= 1_000L })
        // Monotonic ordering.
        assertEquals(log.map { it.timestampMillis }.sorted(), log.map { it.timestampMillis })
    }

    @Test
    fun `duplicate suppression is logged`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())
        engine.processLiveTranscript("What is RAG?")
        engine.processLiveTranscript("What is RAG?")

        val suppressed = engine.eventLog().filterIsInstance<ConversationEvent.Suppressed>().single()
        assertEquals(SuppressionReason.DUPLICATE, suppressed.reason)
    }

    @Test
    fun `reset clears memory dedup and active answer`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        engine.processLiveTranscript("What is RAG?")
        engine.reset()

        assertNull(engine.activeAnswer)
        assertTrue(engine.transcriptContext().isEmpty())
        assertTrue(engine.eventLog().isEmpty())

        // The same question is answerable again after a reset.
        val turn = engine.processLiveTranscript("What is RAG?")
        assertNotNull(turn.answer)
        assertEquals(2, provider.requests.size)
    }

    @Test
    fun `blank transcript is a no-op`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        val turn = engine.processLiveTranscript("   ")

        assertNull(turn.question)
        assertNull(turn.answer)
        assertTrue(engine.eventLog().isEmpty())
        assertTrue(provider.requests.isEmpty())
    }

    @Test
    fun `setProvider swaps the answer source`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())
        val replacement = RecordingProvider()
        engine.setProvider(replacement)

        engine.processLiveTranscript("What is RAG?")

        assertEquals(1, replacement.requests.size)
    }
}
