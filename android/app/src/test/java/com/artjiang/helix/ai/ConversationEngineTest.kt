package com.artjiang.helix.ai

import com.artjiang.helix.HudAnsweredTurn
import com.artjiang.helix.hudAnswerPresentation
import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import java.util.concurrent.atomic.AtomicLong
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

        override suspend fun answer(
            request: AnswerRequest,
            onDelta: ((String) -> Unit)?,
        ): AnswerResponse {
            requests += request
            error?.let { throw it }
            val text = "answer for ${request.question}"
            onDelta?.invoke(text)
            return AnswerResponse(text, kind, model)
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
    fun `provider failure releases duplicate reservation so the question can retry`() = runTest {
        val failing = RecordingProvider(error = IllegalStateException("temporary outage"))
        val succeeding = RecordingProvider()
        val engine = ConversationEngine(provider = failing)

        val failed = engine.processLiveTranscript("What is RAG?")
        engine.setProvider(succeeding)
        val retried = engine.processLiveTranscript("What is RAG?")

        assertEquals(SuppressionReason.PROVIDER_ERROR, failed.suppressed)
        assertNotNull("a failed provider call must not poison ten minutes of retries", retried.answer)
        assertEquals(1, succeeding.requests.size)
    }

    @Test
    fun `cancelled provider releases duplicate reservation so the question can retry`() = runTest {
        val cancelled = RecordingProvider(error = CancellationException("session interrupted"))
        val succeeding = RecordingProvider()
        val engine = ConversationEngine(provider = cancelled)

        runCatching { engine.processLiveTranscript("What is RAG?") }
        engine.setProvider(succeeding)
        val retried = engine.processLiveTranscript("What is RAG?")

        assertNotNull("cancellation before delivery must release the reservation", retried.answer)
    }

    @Test
    fun `question heard while auto answer is off remains eligible after enabling it`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(autoAnswer = false),
            provider = provider,
        )

        val disabled = engine.processLiveTranscript("What is RAG?")
        engine.updateSettings(HelixSettings(autoAnswer = true))
        val enabled = engine.processLiveTranscript("What is RAG?")

        assertEquals(SuppressionReason.AUTO_ANSWER_DISABLED, disabled.suppressed)
        assertNotNull("the disabled pass must not reserve the question", enabled.answer)
        assertEquals(1, provider.requests.size)
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
            HelixSettings(mode = ConversationMode.ACTIVE, maxResponseSentences = 5),
        )
        engine.processLiveTranscript("Why should we hire you?")

        val request = provider.requests.single()
        assertEquals(ConversationMode.ACTIVE, request.mode)
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

    // MARK: Recent-context (on-demand) answers

    @Test
    fun `answerFromRecentContext sends the sentinel and the window and reports the detected question`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)
        val window = "We ship on Tuesday.\nWhat is the rollback plan?\nI think a flag flip."

        val turn = engine.answerFromRecentContext(window)

        val request = provider.requests.single()
        assertEquals(PromptBuilder.RECENT_CONTEXT_QUESTION, request.question)
        assertEquals(window, request.conversationContext)
        assertTrue(PromptBuilder.isRecentContextRequest(request))

        assertNotNull(turn.question)
        assertEquals("What is the rollback plan?", turn.question!!.text)
        assertNotNull(turn.answer)
        assertEquals("I think a flag flip.", turn.transcript)
        assertEquals(turn.answer, engine.activeAnswer)
        val memory = engine.transcriptContext()
        assertTrue(memory, memory.contains("Q: What is the rollback plan?"))
        assertFalse(memory.contains(ConversationEngine.RECENT_CONTEXT_MEMORY_LABEL))
        assertTrue(engine.eventLog().any { it is ConversationEvent.QuestionDetected })
    }

    @Test
    fun `answerFromRecentContext fallback never remembers a fabricated question`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        val turn = engine.answerFromRecentContext("The meeting is at three.\nWe should book the big room.")

        assertEquals(1, provider.requests.size)
        assertNull("fallback candidate must not be reported as a question", turn.question)
        assertNotNull(turn.answer)
        val memory = engine.transcriptContext()
        assertTrue(memory, memory.contains("Q: ${ConversationEngine.RECENT_CONTEXT_MEMORY_LABEL}"))
        assertFalse(memory.contains("Q: We should book the big room."))
        assertTrue(memory.contains("A: answer for ${PromptBuilder.RECENT_CONTEXT_QUESTION}"))
        assertFalse(engine.eventLog().any { it is ConversationEvent.QuestionDetected })
        assertTrue(engine.eventLog().any { it is ConversationEvent.AnswerStarted })
    }

    @Test
    fun `answerFromRecentContext bypasses detection gates and duplicate suppression`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(autoDetectQuestions = false, autoAnswer = false),
            provider = provider,
        )
        engine.processLiveTranscript("What is RAG?")
        assertEquals(0, provider.requests.size)

        engine.answerFromRecentContext("What is RAG?")
        engine.answerFromRecentContext("What is RAG?")
        assertEquals(2, provider.requests.size)
    }

    @Test
    fun `answerFromRecentContext with a blank window is a no-op`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)
        val turn = engine.answerFromRecentContext("  \n ")
        assertNull(turn.answer)
        assertNull(turn.question)
        assertTrue(provider.requests.isEmpty())
    }

    @Test
    fun `answerFromRecentContext provider failure surfaces as provider error`() = runTest {
        val provider = RecordingProvider(error = IllegalStateException("boom"))
        val engine = ConversationEngine(provider = provider)
        val turn = engine.answerFromRecentContext("Can you explain?")
        assertEquals(SuppressionReason.PROVIDER_ERROR, turn.suppressed)
        assertNotNull(turn.error)
        assertNull(engine.activeAnswer)
    }

    @Test
    fun `reset lets a previously asked question be answered again`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())

        val first = engine.processLiveTranscript("What is the deadline?")
        assertNotNull("the first ask must be answered", first.answer)

        val suppressed = engine.processLiveTranscript("What is the deadline?")
        assertNull("an immediate repeat is still suppressed", suppressed.answer)

        engine.reset()

        val afterReset = engine.processLiveTranscript("What is the deadline?")
        assertNotNull(
            "after reset the same question must be answerable again",
            afterReset.answer,
        )
    }

    // MARK: Two-tier provider routing

    @Test
    fun `auto-detected question uses the fast provider, manual asks use the smart provider`() = runTest {
        val fast = RecordingProvider(model = "fast-model")
        val smart = RecordingProvider(model = "smart-model")
        val engine = ConversationEngine(provider = DeterministicProvider())
        engine.setProviders(fast = fast, smart = smart)

        val autoTurn = engine.processLiveTranscript("What is an LLM?")
        assertEquals("auto-detected turn is answered", 1, fast.requests.size)
        assertEquals("smart provider untouched by the auto path", 0, smart.requests.size)
        assertEquals("fast-model", autoTurn.answer!!.model)

        val manualTurn = engine.answerTextQuestion("Explain transformers in depth")
        assertEquals("manual ask reaches the smart provider", 1, smart.requests.size)
        assertEquals("fast provider untouched by the manual ask", 1, fast.requests.size)
        assertEquals("smart-model", manualTurn.answer!!.model)

        val recentContextTurn = engine.answerFromRecentContext("Heard: some earlier context")
        assertEquals("recent-context ask also reaches the smart provider", 2, smart.requests.size)
        assertEquals("fast provider still untouched", 1, fast.requests.size)
        assertEquals("smart-model", recentContextTurn.answer!!.model)
    }

    @Test
    fun `setProvider sets both tiers to the same instance`() = runTest {
        val shared = RecordingProvider(model = "shared-model")
        val engine = ConversationEngine(provider = DeterministicProvider())
        engine.setProvider(shared)

        val autoTurn = engine.processLiveTranscript("What is RAG?")
        val manualTurn = engine.answerTextQuestion("What is attention?")

        assertEquals(2, shared.requests.size)
        assertEquals("shared-model", autoTurn.answer!!.model)
        assertEquals("shared-model", manualTurn.answer!!.model)
    }

    // MARK: Multiple questions in one transcript block (was `.firstOrNull()`
    // on the live path vs `.lastOrNull()` on the recent-context path — the
    // two disagreed about which question in the SAME block was "the"
    // question, and the live path silently dropped every question after the
    // first).

    @Test
    fun `one finalized segment preserves and answers every distinct question`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        val turns = engine.processLiveTranscriptTurns("What is RAG? How does it help?")

        assertEquals(
            listOf("What is RAG?", "How does it help?"),
            turns.mapNotNull { it.question?.text },
        )
        assertEquals(
            listOf("What is RAG?", "How does it help?"),
            provider.requests.map { it.question },
        )
        assertTrue(turns.all { it.answer != null })
    }

    @Test
    fun `detector through engine and combined HUD preserves mixed-confidence spoken order`() = runTest {
        val transcript = "Can you explain RAG. What are its limitations?"
        val provider = RecordingProvider()
        val detector = LlmQuestionDetector(
            classify = { """["Can you explain RAG."]""" },
        )
        val engine = ConversationEngine(provider = provider, llmDetector = detector)

        val turns = engine.processLiveTranscriptTurns(transcript, deferStateCommit = true)
        val presentation = hudAnswerPresentation(
            turns.map {
                HudAnsweredTurn(
                    question = it.question?.text,
                    answer = it.answer?.text.orEmpty(),
                    feedEntryId = null,
                )
            },
        )!!

        val spokenOrder = listOf("Can you explain RAG.", "What are its limitations?")
        assertEquals(spokenOrder, turns.mapNotNull { it.question?.text })
        assertEquals(spokenOrder, provider.requests.map { it.question })
        assertTrue(presentation.text.indexOf(spokenOrder[0]) < presentation.text.indexOf(spokenOrder[1]))
    }

    @Test
    fun `same-segment questions can finish provider work concurrently and retain spoken order`() = runTest {
        val firstStarted = CompletableDeferred<Unit>()
        val releaseFirst = CompletableDeferred<Unit>()
        val secondFinished = CompletableDeferred<Unit>()
        val provider = object : AnswerProvider {
            override val kind = ProviderKind.DETERMINISTIC
            override val model = "concurrent"

            override suspend fun answer(
                request: AnswerRequest,
                onDelta: ((String) -> Unit)?,
            ): AnswerResponse {
                if (request.question == "What is RAG?") {
                    firstStarted.complete(Unit)
                    releaseFirst.await()
                } else {
                    secondFinished.complete(Unit)
                }
                return AnswerResponse("answer for ${request.question}", kind, model)
            }
        }
        val engine = ConversationEngine(provider = provider)

        val result = async {
            engine.processLiveTranscriptTurns(
                "What is RAG? How does it help?",
                deferStateCommit = true,
            )
        }
        firstStarted.await()
        secondFinished.await()
        assertFalse("the first provider is deliberately still blocked", result.isCompleted)

        releaseFirst.complete(Unit)
        val turns = result.await()
        assertEquals(
            listOf("What is RAG?", "How does it help?"),
            turns.mapNotNull { it.question?.text },
        )
    }

    @Test
    fun `later final can classify while an earlier classifier is blocked`() = runTest {
        val firstClassifierStarted = CompletableDeferred<Unit>()
        val releaseFirstClassifier = CompletableDeferred<Unit>()
        val secondClassified = CompletableDeferred<Unit>()
        val llmDetector = LlmQuestionDetector(
            classify = { prompt ->
                when {
                    prompt.contains("alpha topic") -> {
                        firstClassifierStarted.complete(Unit)
                        releaseFirstClassifier.await()
                        """["Please explain the alpha topic"]"""
                    }

                    else -> {
                        secondClassified.complete(Unit)
                        """["Please explain the beta topic"]"""
                    }
                }
            },
        )
        val engine = ConversationEngine(
            provider = RecordingProvider(),
            llmDetector = llmDetector,
        )

        val first = async {
            engine.processLiveTranscriptTurns(
                "Please explain the alpha topic",
                deferStateCommit = true,
            )
        }
        firstClassifierStarted.await()
        val second = async {
            engine.processLiveTranscriptTurns(
                "Please explain the beta topic",
                deferStateCommit = true,
            )
        }

        secondClassified.await()
        assertFalse("the first classifier is deliberately still blocked", first.isCompleted)
        releaseFirstClassifier.complete(Unit)
        assertNotNull(first.await().single().answer)
        assertNotNull(second.await().single().answer)
    }

    @Test
    fun `first-arriving identical implicit question owns dedupe despite classifier completion order`() = runTest {
        val firstClassifierStarted = CompletableDeferred<Unit>()
        val releaseFirstClassifier = CompletableDeferred<Unit>()
        val secondClassified = CompletableDeferred<Unit>()
        val provider = RecordingProvider()
        val detector = LlmQuestionDetector(
            classify = { prompt ->
                if (prompt.contains("first utterance")) {
                    firstClassifierStarted.complete(Unit)
                    releaseFirstClassifier.await()
                } else {
                    secondClassified.complete(Unit)
                }
                """["Please review the proposal"]"""
            },
        )
        val engine = ConversationEngine(provider = provider, llmDetector = detector)

        val first = async {
            engine.processLiveTranscriptTurns(
                "first utterance: Please review the proposal",
                deferStateCommit = true,
            )
        }
        firstClassifierStarted.await()
        val second = async {
            engine.processLiveTranscriptTurns(
                "later utterance: Please review the proposal",
                deferStateCommit = true,
            )
        }
        secondClassified.await()
        assertTrue("dedupe preparation waits for arrival order, not classifier order", provider.requests.isEmpty())

        releaseFirstClassifier.complete(Unit)
        val firstTurns = first.await()
        val secondTurns = second.await()
        assertNotNull(firstTurns.single().answer)
        assertEquals(SuppressionReason.DUPLICATE, secondTurns.single().suppressed)
        assertEquals(listOf("Please review the proposal"), provider.requests.map { it.question })
    }

    @Test
    fun `deferred ordered commit preserves measured provider latency`() = runTest {
        val now = AtomicLong(1_000L)
        val provider = object : AnswerProvider {
            override val kind = ProviderKind.DETERMINISTIC
            override val model = "timed"

            override suspend fun answer(
                request: AnswerRequest,
                onDelta: ((String) -> Unit)?,
            ): AnswerResponse {
                now.addAndGet(137L)
                return AnswerResponse("Timed answer text.", kind, model)
            }
        }
        val engine = ConversationEngine(provider = provider, clock = { now.get() })

        val turns = engine.processLiveTranscriptTurns(
            "What is RAG?",
            deferStateCommit = true,
        )
        assertTrue(engine.eventLog().none { it is ConversationEvent.AnswerCompleted })
        engine.commitLiveTranscriptTurns(turns)

        val completed = engine.eventLog().filterIsInstance<ConversationEvent.AnswerCompleted>().single()
        assertEquals(137L, completed.latencyMillis)
        assertEquals(137L, turns.single().providerLatencyMillis)
    }

    @Test
    fun `multi-question segment deduplicates each question independently`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)
        engine.processLiveTranscript("What is RAG?")

        val turns = engine.processLiveTranscriptTurns("What is RAG? How does it help?")

        assertEquals(SuppressionReason.DUPLICATE, turns[0].suppressed)
        assertNotNull("the distinct second question must still be answered", turns[1].answer)
        assertEquals(
            listOf("What is RAG?", "How does it help?"),
            provider.requests.map { it.question },
        )
    }

    @Test
    fun `singular compatibility result is highest confidence while every question is answered`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        // "How does it help?" (a plain punctuation question, 0.95) plus a
        // trailing Chinese A-not-A question (0.60) in the same block: the
        // higher-confidence one remains the representative singular result,
        // while both questions must now reach the provider.
        val turn = engine.processLiveTranscript("How does it help? 有没有别的办法")

        assertEquals("How does it help?", turn.question!!.text)
        assertEquals(listOf("How does it help?", "有没有别的办法"), provider.requests.map { it.question })
    }

    @Test
    fun `live path answers the most recent question on a confidence tie`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(provider = provider)

        // Both are plain "?" questions (same PUNCTUATION_CONFIDENCE) — before
        // this fix .firstOrNull() would have answered "What is RAG?" and
        // silently dropped "How does it help?" entirely.
        val turn = engine.processLiveTranscript("What is RAG? How does it help?")

        assertEquals(
            "on a confidence tie the most recently spoken question is answered",
            "How does it help?",
            turn.question!!.text,
        )
    }

    @Test
    fun `all answered questions from a multi-question block are logged`() = runTest {
        val engine = ConversationEngine(provider = DeterministicProvider())

        engine.processLiveTranscript("What is RAG? How does it help?")

        val detected = engine.eventLog().filterIsInstance<ConversationEvent.QuestionDetected>()
        assertTrue(
            "every detected question must appear in the event log",
            detected.any { it.question.text == "What is RAG?" },
        )
        assertTrue(
            detected.any { it.question.text == "How does it help?" },
        )
    }

    @Test
    fun `live path and recent-context path agree on which question in the same block is THE question`() = runTest {
        val liveProvider = RecordingProvider()
        val liveEngine = ConversationEngine(provider = liveProvider)
        val contextProvider = RecordingProvider()
        val contextEngine = ConversationEngine(provider = contextProvider)

        val block = "What is RAG? How does it help?"
        val liveTurn = liveEngine.processLiveTranscript(block)
        // answerFromRecentContext always sends the sentinel question to the
        // provider; what matters here is which question the engine itself
        // reports as "detected" in Turn.question.
        val contextTurn = contextEngine.answerFromRecentContext(block)

        assertEquals(
            "both paths must pick the same question out of an identical block",
            liveTurn.question!!.text,
            contextTurn.question!!.text,
        )
    }

    @Test
    fun `llm detector is used on the live path when provided`() = runTest {
        val provider = RecordingProvider()
        var classifyCalls = 0
        val llmDetector = LlmQuestionDetector(
            classify = { text ->
                classifyCalls++
                """["你能帮我看一下这个报错"]"""
            },
        )
        val engine = ConversationEngine(provider = provider, llmDetector = llmDetector)

        // No "?", no particle, no A-not-A, no listed interrogative: only the
        // LLM detector can find this one.
        val turn = engine.processLiveTranscript("你能帮我看一下这个报错")

        assertEquals(1, classifyCalls)
        assertNotNull("the LLM-only question must be answered", turn.answer)
        assertEquals("你能帮我看一下这个报错", turn.question!!.text)
    }
}
