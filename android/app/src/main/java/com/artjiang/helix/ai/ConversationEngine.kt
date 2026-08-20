package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.QuestionCandidate
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Why a detected question produced no answer. */
enum class SuppressionReason {
    /** Auto-detect is off, so the transcript was never scanned. */
    DETECTION_DISABLED,

    /** This question was already answered in this session. */
    DUPLICATE,

    /** Auto-answer is off — the question is surfaced but not answered. */
    AUTO_ANSWER_DISABLED,

    /** The provider call failed. */
    PROVIDER_ERROR,
}

/** One pass of the live-transcript pipeline. */
data class Turn(
    val transcript: String,
    val question: QuestionCandidate? = null,
    val answer: AnswerResponse? = null,
    val suppressed: SuppressionReason? = null,
    val error: Throwable? = null,
) {
    val hasAnswer: Boolean get() = answer != null
}

/** Typed, timestamped pipeline events for the UI log. */
sealed class ConversationEvent {
    abstract val timestampMillis: Long

    data class TranscriptReceived(
        val text: String,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class QuestionDetected(
        val question: QuestionCandidate,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class AnswerStarted(
        val question: QuestionCandidate,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class AnswerCompleted(
        val answer: AnswerResponse,
        val latencyMillis: Long,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class Suppressed(
        val reason: SuppressionReason,
        val detail: String,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class Failed(
        val error: Throwable,
        override val timestampMillis: Long,
    ) : ConversationEvent()

    data class SettingsUpdated(
        val settings: HelixSettings,
        override val timestampMillis: Long,
    ) : ConversationEvent()
}

/**
 * Live conversation pipeline: question detection -> dedup -> auto-answer gate ->
 * provider answer, with a capped rolling transcript window fed back into
 * [AnswerRequest.conversationContext].
 *
 * Mutation is serialized behind a [Mutex] rather than an actor (the Swift
 * `NativeConversationEngine` is an `actor`), which gives the same
 * one-writer-at-a-time guarantee for coroutine callers.
 */
class ConversationEngine(
    settings: HelixSettings = HelixSettings(),
    private var provider: AnswerProvider = DeterministicProvider(),
    private val detector: QuestionDetector = QuestionDetector(),
    private val suppressor: DuplicateQuestionSuppressor = DuplicateQuestionSuppressor(),
    private val knowledgeProvider: suspend (String) -> List<String> = { emptyList() },
    private val transcriptWindowSize: Int = DEFAULT_TRANSCRIPT_WINDOW,
    private val eventLogLimit: Int = DEFAULT_EVENT_LOG_LIMIT,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val mutex = Mutex()

    private var currentSettings: HelixSettings = settings
    private val transcriptWindow = ArrayDeque<String>()
    private val events = mutableListOf<ConversationEvent>()

    /**
     * The most recent answer, or null once a newer transcript arrives.
     *
     * iOS kept an `EvenAI.hasActiveAnswer` flag that outlived the answer it
     * described, so the touchpad kept paging a stale answer. Here the state is
     * cleared at the top of every [processLiveTranscript], so "is an answer
     * currently on the HUD" can never drift from what was actually produced.
     */
    var activeAnswer: AnswerResponse? = null
        private set

    val settings: HelixSettings get() = currentSettings

    fun eventLog(): List<ConversationEvent> = events.toList()

    fun transcriptContext(): String = transcriptWindow.joinToString("\n")

    suspend fun updateSettings(settings: HelixSettings) = mutex.withLock {
        currentSettings = settings
        log(ConversationEvent.SettingsUpdated(settings, clock()))
    }

    suspend fun setProvider(provider: AnswerProvider) = mutex.withLock {
        this.provider = provider
    }

    /** Clears session memory, dedup state, the active answer and the event log. */
    suspend fun reset() = mutex.withLock {
        transcriptWindow.clear()
        suppressor.reset()
        activeAnswer = null
        events.clear()
    }

    /**
     * Runs the live-transcript pipeline for one finalized transcript segment.
     */
    suspend fun processLiveTranscript(text: String): Turn = mutex.withLock {
        val transcript = text.trim()
        // A new transcript always invalidates the previous answer's active state.
        activeAnswer = null

        if (transcript.isEmpty()) return@withLock Turn(transcript = transcript)

        log(ConversationEvent.TranscriptReceived(transcript, clock()))
        // Context is the history *before* this utterance; snapshot it before
        // the current line enters the window so the provider isn't handed the
        // question twice.
        val priorContext = transcriptContext()
        rememberTranscript(transcript)

        if (!currentSettings.autoDetectQuestions) {
            log(
                ConversationEvent.Suppressed(
                    SuppressionReason.DETECTION_DISABLED,
                    "Auto-detect questions is off.",
                    clock(),
                ),
            )
            return@withLock Turn(
                transcript = transcript,
                suppressed = SuppressionReason.DETECTION_DISABLED,
            )
        }

        val candidate = detector.detectQuestions(transcript).firstOrNull()
            ?: return@withLock Turn(transcript = transcript)

        log(ConversationEvent.QuestionDetected(candidate, clock()))

        if (!suppressor.markIfNew(candidate.text)) {
            log(
                ConversationEvent.Suppressed(
                    SuppressionReason.DUPLICATE,
                    candidate.text,
                    clock(),
                ),
            )
            return@withLock Turn(
                transcript = transcript,
                question = candidate,
                suppressed = SuppressionReason.DUPLICATE,
            )
        }

        if (!currentSettings.autoAnswer) {
            log(
                ConversationEvent.Suppressed(
                    SuppressionReason.AUTO_ANSWER_DISABLED,
                    candidate.text,
                    clock(),
                ),
            )
            return@withLock Turn(
                transcript = transcript,
                question = candidate,
                suppressed = SuppressionReason.AUTO_ANSWER_DISABLED,
            )
        }

        answerLocked(candidate, transcript, priorContext)
    }

    /**
     * Answers a typed question. Bypasses detection and the auto-answer gate —
     * an explicit ask is always answered — but still records the exchange.
     */
    suspend fun answerTextQuestion(text: String): Turn = mutex.withLock {
        val question = text.trim()
        if (question.isEmpty()) return@withLock Turn(transcript = question)

        val candidate = QuestionCandidate(question, QuestionDetector.PUNCTUATION_CONFIDENCE)
        log(ConversationEvent.QuestionDetected(candidate, clock()))
        suppressor.markIfNew(question)
        answerLocked(candidate, question, transcriptContext())
    }

    /** Caller must hold [mutex]. */
    private suspend fun answerLocked(
        candidate: QuestionCandidate,
        transcript: String,
        conversationContext: String,
    ): Turn {
        log(ConversationEvent.AnswerStarted(candidate, clock()))
        val startedAt = clock()

        val request = AnswerRequest(
            question = candidate.text,
            mode = currentSettings.mode,
            skill = currentSettings.activeSkill,
            maxResponseSentences = currentSettings.maxResponseSentences,
            conversationContext = conversationContext,
            knowledgeContext = runCatching { knowledgeProvider(candidate.text) }.getOrDefault(emptyList()),
        )

        return try {
            val answer = provider.answer(request)
            activeAnswer = answer
            rememberAnswer(candidate.text, answer.text)
            log(ConversationEvent.AnswerCompleted(answer, clock() - startedAt, clock()))
            Turn(transcript = transcript, question = candidate, answer = answer)
        } catch (error: Throwable) {
            activeAnswer = null
            log(ConversationEvent.Failed(error, clock()))
            Turn(
                transcript = transcript,
                question = candidate,
                suppressed = SuppressionReason.PROVIDER_ERROR,
                error = error,
            )
        }
    }

    private fun rememberTranscript(text: String) = pushWindow("Heard: $text")

    private fun rememberAnswer(question: String, answer: String) {
        pushWindow("Q: $question")
        pushWindow("A: $answer")
    }

    private fun pushWindow(line: String) {
        transcriptWindow.addLast(line)
        while (transcriptWindow.size > transcriptWindowSize) transcriptWindow.removeFirst()
    }

    private fun log(event: ConversationEvent) {
        events += event
        while (events.size > eventLogLimit) events.removeAt(0)
    }

    companion object {
        const val DEFAULT_TRANSCRIPT_WINDOW = 12
        const val DEFAULT_EVENT_LOG_LIMIT = 200
    }
}
