package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.QuestionCandidate
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit

/** Why a detected question produced no answer. */
enum class SuppressionReason {
    /** Auto-detect is off, so the transcript was never scanned. */
    DETECTION_DISABLED,

    /** This question was already answered in this session. */
    DUPLICATE,

    /** Auto-answer is off — the question is surfaced but not answered. */
    AUTO_ANSWER_DISABLED,

    /** Passive mode's trigger classifier decided to stay silent. */
    PASSIVE_FILTERED,

    /** The provider call failed. */
    PROVIDER_ERROR,
}

/**
 * Which provider tier answers a turn. Auto-detected questions get [FAST] (a
 * light/quick model that must visibly stream); a deliberate ask — typed
 * question or "ask now" over recent context — gets [SMART] (the configured
 * smart/reasoning model, which may pause before emitting anything).
 */
@kotlinx.serialization.Serializable
enum class AnswerTier { FAST, SMART }

/** One pass of the live-transcript pipeline. */
data class Turn(
    val transcript: String,
    val question: QuestionCandidate? = null,
    val answer: AnswerResponse? = null,
    val suppressed: SuppressionReason? = null,
    val error: Throwable? = null,
    /** Passive-mode false-claim correction, shown instead of an answer. */
    val passiveReminder: String? = null,
    /** Provider time carried through deferred ordered publication. */
    val providerLatencyMillis: Long? = null,
    /** Provenance for truthful UI actions (FAST may be deliberately deepened once). */
    val answerTier: AnswerTier? = null,
    /** In-flight dedupe claim; committed only when the answer is publishable. */
    val dedupeReservation: DuplicateQuestionSuppressor.Reservation? = null,
)

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

    data class PassiveReminder(
        val reminder: String,
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
    provider: AnswerProvider = DeterministicProvider(),
    private val detector: QuestionDetector = QuestionDetector(),
    /**
     * Optional LLM-backed detector for the live-transcript path. When null
     * (the default — every pre-existing test constructs the engine this
     * way), live detection uses [detector] alone, unchanged. When set, it
     * replaces the heuristic-only detection phase in [processLiveTranscriptTurns] with the LLM
     * detector's pre-filtered, fallback-safe [LlmQuestionDetector.detectQuestions]
     * (which runs its own heuristic pre-filter first, and only calls the
     * model when that pre-filter is not already confident — see
     * [LlmQuestionDetector] for the cost-control rationale).
     */
    private val llmDetector: LlmQuestionDetector? = null,
    private val suppressor: DuplicateQuestionSuppressor = DuplicateQuestionSuppressor(),
    private val passiveClassifier: PassiveTriggerClassifier = PassiveTriggerClassifier(),
    private val passiveCorrections: PassiveCorrectionDetector = PassiveCorrectionDetector(),
    private val knowledgeProvider: suspend (String) -> List<String> = { emptyList() },
    private val transcriptWindowSize: Int = DEFAULT_TRANSCRIPT_WINDOW,
    private val eventLogLimit: Int = DEFAULT_EVENT_LOG_LIMIT,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val mutex = Mutex()

    /**
     * Two-tier answer providers. Auto-detected questions ([processLiveTranscript])
     * use [fastProvider] so the HUD sees tokens quickly; a deliberate ask
     * ([answerTextQuestion], [answerFromRecentContext]) uses [smartProvider],
     * which may be a slower reasoning model that emits nothing while thinking.
     * [setProvider] (single-provider callers, and every pre-tiering test) sets
     * both tiers to the same instance, matching the old one-provider behavior.
     */
    private var fastProvider: AnswerProvider = provider
    private var smartProvider: AnswerProvider = provider

    private var currentSettings: HelixSettings = settings
    private val transcriptWindow = ArrayDeque<String>()
    private val events = mutableListOf<ConversationEvent>()
    /** Serializes only post-classification dedupe/preparation in arrival order. */
    private var detectionPreparationTail = CompletableDeferred(Unit)

    /**
     * Bumped on every new transcript/typed question. An answer that finishes
     * after a newer turn started must not overwrite [activeAnswer] — the lock
     * is released across the provider call (see [answerPrepared]), so this is
     * the staleness check.
     */
    private var turnGeneration: Long = 0

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

    /** Sets both tiers to the same provider — the pre-tiering, single-provider shape. */
    suspend fun setProvider(provider: AnswerProvider) = mutex.withLock {
        this.fastProvider = provider
        this.smartProvider = provider
    }

    /**
     * Sets both tiers independently. [fast] answers auto-detected questions;
     * [smart] answers deliberate asks (typed question, recent-context "ask now").
     */
    suspend fun setProviders(fast: AnswerProvider, smart: AnswerProvider) = mutex.withLock {
        this.fastProvider = fast
        this.smartProvider = smart
    }

    /** Clears session memory, dedup state, the active answer and the event log. */
    suspend fun reset() = mutex.withLock {
        transcriptWindow.clear()
        suppressor.reset()
        detectionPreparationTail = CompletableDeferred(Unit)
        activeAnswer = null
        events.clear()
    }

    /**
     * Runs the live-transcript pipeline for one finalized transcript segment.
     *
     * The mutex guards only state mutation; the provider's network round-trip
     * runs outside it so new transcripts, settings updates, and typed
     * questions never queue behind an in-flight answer (the Swift actor this
     * mirrors releases isolation at every `await` — holding the lock across
     * the HTTP call was stricter than the reference and lagged the pipeline).
     */
    suspend fun processLiveTranscript(
        text: String,
        onAnswerDelta: ((String) -> Unit)? = null,
    ): Turn {
        val batchDeltaSink = onAnswerDelta?.let { sink ->
            { _: QuestionCandidate, chunk: String -> sink(chunk) }
        }
        val turns = processLiveTranscriptTurns(
            text = text,
            onAnswerDelta = batchDeltaSink,
        )
        return primaryTurn(turns)
    }

    /**
     * Runs every question in one finalized transcript through the live answer
     * path. Detection can legitimately return more than one question for one
     * ASR final; reducing that list to one candidate silently lost the rest.
     *
     * Each candidate gets its own duplicate/auto-answer decision and provider
     * request. The bridge's deferred path runs those requests with a small
     * concurrency bound, then its queue publishes them in spoken order. The
     * singular [processLiveTranscript] remains a compatibility convenience and
     * returns the highest-ranked useful turn, but still executes every turn.
     */
    suspend fun processLiveTranscriptTurns(
        text: String,
        onAnswerStarted: ((QuestionCandidate) -> Unit)? = null,
        onAnswerDelta: ((QuestionCandidate, String) -> Unit)? = null,
        onTurnCompleted: (suspend (Turn) -> Unit)? = null,
        /** Bridge queues defer engine memory/HUD-active mutation until ordered publication. */
        deferStateCommit: Boolean = false,
    ): List<Turn> {
        val beginning = mutex.withLock { beginLiveTurn(text) }
        val preps = when (beginning) {
            is LiveTurnBeginning.Terminal -> beginning.preps
            is LiveTurnBeginning.NeedsDetection -> {
                // Classification is network work. Never hold the engine mutex
                // while awaiting it: another finalized segment must be able to
                // reserve its transcript context and classify concurrently.
                try {
                    val candidates = if (llmDetector != null) {
                        llmDetector.detectQuestions(beginning.transcript)
                    } else {
                        detector.detectQuestions(beginning.transcript)
                    }
                    // Classification runs concurrently, but duplicate ownership
                    // is awarded in transcript-arrival order. This barrier ends
                    // before any provider call, so a slow provider still cannot
                    // block a later question's provider work.
                    beginning.predecessor.await()
                    mutex.withLock { prepareDetectedTurns(beginning, candidates) }
                } finally {
                    beginning.completion.complete(Unit)
                }
            }
        }
        suspend fun execute(prep: TurnPrep): Turn = when (prep) {
                is TurnPrep.Done -> prep.turn
                is TurnPrep.Answer -> {
                    onAnswerStarted?.invoke(prep.candidate)
                    val deltaSink = onAnswerDelta?.let { sink ->
                        { chunk: String -> sink(prep.candidate, chunk) }
                    }
                    answerPrepared(
                        prep = prep,
                        onAnswerDelta = deltaSink,
                        commitState = !deferStateCommit,
                        enforceGeneration = !deferStateCommit,
                    )
                }
            }

        val turns = if (deferStateCommit && preps.size > 1) {
            coroutineScope {
                val permits = Semaphore(MAX_CONCURRENT_BATCH_ANSWERS)
                preps.map { prep -> async { permits.withPermit { execute(prep) } } }.awaitAll()
            }
        } else {
            preps.map { prep -> execute(prep) }
        }
        turns.forEach { turn -> onTurnCompleted?.invoke(turn) }
        return turns
    }

    /**
     * Commits a deferred live batch after the bridge's ordered queue reaches
     * it. Provider completion order must not decide conversation memory or the
     * answer touchpad considers active.
     */
    suspend fun commitLiveTranscriptTurns(turns: List<Turn>) = mutex.withLock {
        for (turn in turns) {
            val answer = turn.answer
            when {
                answer != null -> {
                    turn.dedupeReservation?.let(suppressor::commit)
                    activeAnswer = answer
                    turn.question?.let { question -> rememberAnswer(question.text, answer.text) }
                    log(
                        ConversationEvent.AnswerCompleted(
                            answer,
                            latencyMillis = turn.providerLatencyMillis ?: 0L,
                            timestampMillis = clock(),
                        ),
                    )
                }

                turn.error != null -> {
                    turn.dedupeReservation?.let(suppressor::release)
                    activeAnswer = null
                    log(ConversationEvent.Failed(turn.error, clock()))
                }
            }
        }
    }

    /**
     * Answers a typed question. Bypasses detection and the auto-answer gate —
     * an explicit ask is always answered — but still records the exchange.
     */
    suspend fun answerTextQuestion(
        text: String,
        onAnswerDelta: ((String) -> Unit)? = null,
    ): Turn {
        val prep = mutex.withLock {
            val question = text.trim()
            if (question.isEmpty()) return@withLock TurnPrep.Done(Turn(transcript = question))

            // An explicit ask supersedes any answer still in flight.
            turnGeneration += 1
            val candidate = QuestionCandidate(question, QuestionDetector.PUNCTUATION_CONFIDENCE)
            log(ConversationEvent.QuestionDetected(candidate, clock()))
            prepareAnswer(
                candidate,
                question,
                transcriptContext(),
                tier = AnswerTier.SMART,
                dedupeReservation = suppressor.reserveIfAvailable(question),
            )
        }
        return when (prep) {
            is TurnPrep.Done -> prep.turn
            is TurnPrep.Answer -> answerPrepared(prep, onAnswerDelta)
        }
    }

    /**
     * On-demand path: answers whatever most recently needed an answer in
     * [window] (the last ~minute of transcript, oldest first). No question
     * detection gate, no duplicate suppression, no auto-answer gate — the user
     * explicitly asked. The provider gets [PromptBuilder.RECENT_CONTEXT_QUESTION]
     * as the question and the window as context, so it picks the question
     * itself; the engine's own detector only supplies the *displayed* guess.
     *
     * Memory hygiene: only a question the detector actually found is written
     * back as a `Q:` line and reported as [Turn.question]. When the candidate
     * is a fallback (the last line of the window) the exchange is remembered
     * as "(asked from recent context)" so saved-session titles and later
     * prompts never carry a fabricated question.
     */
    suspend fun answerFromRecentContext(
        window: String,
        onAnswerDelta: ((String) -> Unit)? = null,
    ): Turn {
        val prep = mutex.withLock {
            val context = window.trim()
            if (context.isEmpty()) return@withLock TurnPrep.Done(Turn(transcript = context))

            // An explicit ask supersedes any answer still in flight.
            turnGeneration += 1
            val lines = context.lines().map { it.trim() }.filter { it.isNotEmpty() }
            // Same selection rule as the live path (see selectAnswerCandidate):
            // highest confidence, most-recent on a tie. Previously this used
            // .lastOrNull() while the live path used .firstOrNull() — the two
            // on-demand and live-transcript paths could disagree about which
            // question in the SAME block was "the" question.
            val detected = selectAnswerCandidate(detector.detectQuestions(context))
            detected?.let { log(ConversationEvent.QuestionDetected(it, clock())) }
            val candidate = detected ?: QuestionCandidate(lines.last(), RECENT_CONTEXT_FALLBACK_CONFIDENCE)
            prepareAnswer(
                candidate = candidate,
                transcript = lines.last(),
                conversationContext = context,
                questionOverride = PromptBuilder.RECENT_CONTEXT_QUESTION,
                rememberAsQuestion = detected != null,
                tier = AnswerTier.SMART,
            )
        }
        return when (prep) {
            is TurnPrep.Done -> prep.turn
            is TurnPrep.Answer -> answerPrepared(prep, onAnswerDelta)
        }
    }

    /** Outcome of the locked preparation phase. */
    private sealed interface TurnPrep {
        data class Done(val turn: Turn) : TurnPrep

        data class Answer(
            val candidate: QuestionCandidate,
            val transcript: String,
            val request: AnswerRequest,
            val provider: AnswerProvider,
            val tier: AnswerTier,
            val generation: Long,
            val startedAt: Long,
            /** False when [candidate] is a recent-context fallback, not a detected question. */
            val rememberAsQuestion: Boolean = true,
            val dedupeReservation: DuplicateQuestionSuppressor.Reservation? = null,
        ) : TurnPrep
    }

    private sealed interface LiveTurnBeginning {
        data class Terminal(val preps: List<TurnPrep>) : LiveTurnBeginning
        data class NeedsDetection(
            val transcript: String,
            val priorContext: String,
            val predecessor: CompletableDeferred<Unit>,
            val completion: CompletableDeferred<Unit>,
        ) : LiveTurnBeginning
    }

    /** Caller must hold [mutex]. */
    private fun beginLiveTurn(text: String): LiveTurnBeginning {
        val transcript = text.trim()
        // A new transcript always invalidates the previous answer's active
        // state — and any answer still in flight for an older transcript.
        activeAnswer = null
        turnGeneration += 1

        if (transcript.isEmpty()) {
            return LiveTurnBeginning.Terminal(listOf(TurnPrep.Done(Turn(transcript = transcript))))
        }

        log(ConversationEvent.TranscriptReceived(transcript, clock()))
        // Context is the history *before* this utterance; snapshot it before
        // the current line enters the window so the provider isn't handed the
        // question twice.
        val priorContext = transcriptContext()
        rememberTranscript(transcript)

        if (currentSettings.mode == ConversationMode.PASSIVE) {
            preparePassiveTurn(transcript, priorContext)?.let {
                return LiveTurnBeginning.Terminal(listOf(it))
            }
        }

        if (!currentSettings.autoDetectQuestions) {
            return LiveTurnBeginning.Terminal(
                listOf(
                    TurnPrep.Done(
                        suppress(
                            transcript,
                            null,
                            SuppressionReason.DETECTION_DISABLED,
                            "Auto-detect questions is off.",
                        ),
                    ),
                ),
            )
        }

        val predecessor = detectionPreparationTail
        val completion = CompletableDeferred<Unit>()
        detectionPreparationTail = completion
        return LiveTurnBeginning.NeedsDetection(transcript, priorContext, predecessor, completion)
    }

    /** Caller must hold [mutex]; classification already completed outside it. */
    private suspend fun prepareDetectedTurns(
        beginning: LiveTurnBeginning.NeedsDetection,
        candidates: List<QuestionCandidate>,
    ): List<TurnPrep> {
        val transcript = beginning.transcript
        if (candidates.isEmpty()) return listOf(TurnPrep.Done(Turn(transcript = transcript)))

        val preps = mutableListOf<TurnPrep>()
        for (candidate in candidates) {
            log(ConversationEvent.QuestionDetected(candidate, clock()))
            preps += if (!currentSettings.autoAnswer) {
                TurnPrep.Done(
                    suppress(transcript, candidate, SuppressionReason.AUTO_ANSWER_DISABLED, candidate.text),
                )
            } else {
                val reservation = suppressor.reserveIfAvailable(candidate.text)
                if (reservation == null) {
                    TurnPrep.Done(
                        suppress(transcript, candidate, SuppressionReason.DUPLICATE, candidate.text),
                    )
                } else {
                    prepareAnswer(
                        candidate,
                        transcript,
                        beginning.priorContext,
                        tier = AnswerTier.FAST,
                        dedupeReservation = reservation,
                    )
                }
            }
        }
        return preps
    }

    /**
     * Passive Listener gate (caller must hold [mutex]). Returns a terminal
     * prep for corrections and stay-silent decisions, or null to continue to
     * the answer path when the classifier approves an actual ask. Port of the
     * `mode == .passive` branch in ConversationEngine.swift.
     */
    private fun preparePassiveTurn(transcript: String, priorContext: String): TurnPrep? {
        passiveCorrections.reminder(transcript)?.let { reminder ->
            log(ConversationEvent.PassiveReminder(reminder, clock()))
            return TurnPrep.Done(Turn(transcript = transcript, passiveReminder = reminder))
        }

        val trigger = passiveClassifier.decision(transcript)
        if (trigger.action != PassiveTriggerAction.ANSWER) {
            return TurnPrep.Done(
                suppress(
                    transcript,
                    null,
                    SuppressionReason.PASSIVE_FILTERED,
                    "${trigger.kind.name.lowercase()}: ${trigger.reason}",
                ),
            )
        }
        return null
    }

    /** Chooses a representative turn for singular compatibility callers. */
    private fun primaryTurn(turns: List<Turn>): Turn {
        if (turns.size <= 1) return turns.firstOrNull() ?: Turn(transcript = "")
        val useful = turns.filter { it.answer != null }.ifEmpty { turns.filter { it.question != null } }
        if (useful.isEmpty()) return turns.last()
        val chosen = selectAnswerCandidate(useful.mapNotNull { it.question })
        return useful.lastOrNull { it.question == chosen } ?: useful.last()
    }

    /** Highest confidence, most recent on a confidence tie. */
    private fun selectAnswerCandidate(candidates: List<QuestionCandidate>): QuestionCandidate? {
        if (candidates.isEmpty()) return null
        val ranked = candidates.withIndex().sortedWith(
            compareByDescending<IndexedValue<QuestionCandidate>> { it.value.confidence }
                .thenByDescending { it.index },
        )
        return ranked.first().value
    }

    /** Caller must hold [mutex]. */
    private fun suppress(
        transcript: String,
        candidate: QuestionCandidate?,
        reason: SuppressionReason,
        detail: String,
    ): Turn {
        log(ConversationEvent.Suppressed(reason, detail, clock()))
        return Turn(transcript = transcript, question = candidate, suppressed = reason)
    }

    /**
     * Caller must hold [mutex]. Builds the request; the send happens unlocked.
     * [questionOverride] replaces the question the provider sees (the
     * recent-context sentinel) while [candidate] stays what the UI shows.
     */
    private suspend fun prepareAnswer(
        candidate: QuestionCandidate,
        transcript: String,
        conversationContext: String,
        questionOverride: String? = null,
        rememberAsQuestion: Boolean = true,
        tier: AnswerTier,
        dedupeReservation: DuplicateQuestionSuppressor.Reservation? = null,
    ): TurnPrep.Answer {
        log(ConversationEvent.AnswerStarted(candidate, clock()))
        return TurnPrep.Answer(
            candidate = candidate,
            transcript = transcript,
            request = AnswerRequest(
                question = questionOverride ?: candidate.text,
                mode = currentSettings.mode,
                skill = currentSettings.resolvedSkill(),
                maxResponseSentences = currentSettings.maxResponseSentences,
                conversationContext = conversationContext,
                knowledgeContext = runCatching { knowledgeProvider(candidate.text) }.getOrDefault(emptyList()),
            ),
            provider = when (tier) {
                AnswerTier.FAST -> fastProvider
                AnswerTier.SMART -> smartProvider
            },
            tier = tier,
            generation = turnGeneration,
            startedAt = clock(),
            rememberAsQuestion = rememberAsQuestion,
            dedupeReservation = dedupeReservation,
        )
    }

    /**
     * Runs the provider call outside the mutex, then commits under it.
     *
     * [onAnswerDelta] is forwarded to the provider only when the caller asked
     * for tokens, so a non-streaming caller still gets the buffered request
     * shape. Deltas are gated by the SAME staleness rule as the committed
     * answer: [turnGeneration] is read without the lock (a monotonic Long
     * written only on the mutex-held prepare path, so a stale reader can at
     * worst see the previous value for an instant and drop one delta it would
     * have dropped a moment later anyway). Without this gate a superseded
     * answer would keep painting tokens over the newer turn's live text.
     */
    private suspend fun answerPrepared(
        prep: TurnPrep.Answer,
        onAnswerDelta: ((String) -> Unit)? = null,
        commitState: Boolean = true,
        enforceGeneration: Boolean = true,
    ): Turn {
        // A fallback candidate is only a display guess, never a reported question.
        val reportedQuestion = prep.candidate.takeIf { prep.rememberAsQuestion }
        val deltaSink = onAnswerDelta?.let { sink ->
            { chunk: String ->
                if (!enforceGeneration || turnGeneration == prep.generation) sink(chunk)
            }
        }
        return try {
            val answer = prep.provider.answer(prep.request, deltaSink)
            val latencyMillis = clock() - prep.startedAt
            if (commitState) mutex.withLock {
                // Only an answer for the newest turn is committed. A stale
                // answer must not become the active one (touchpad paging keys
                // off it) nor enter the transcript window, where it would leak
                // a superseded exchange into the next request's context.
                if (turnGeneration == prep.generation) {
                    prep.dedupeReservation?.let(suppressor::commit)
                    activeAnswer = answer
                    rememberAnswer(
                        if (prep.rememberAsQuestion) prep.candidate.text else RECENT_CONTEXT_MEMORY_LABEL,
                        answer.text,
                    )
                    log(ConversationEvent.AnswerCompleted(answer, latencyMillis, clock()))
                } else prep.dedupeReservation?.let(suppressor::release)
            }
            Turn(
                transcript = prep.transcript,
                question = reportedQuestion,
                answer = answer,
                providerLatencyMillis = latencyMillis,
                answerTier = prep.tier,
                dedupeReservation = prep.dedupeReservation,
            )
        } catch (cancelled: CancellationException) {
            mutex.withLock { prep.dedupeReservation?.let(suppressor::release) }
            throw cancelled
        } catch (error: Throwable) {
            val latencyMillis = clock() - prep.startedAt
            if (commitState) mutex.withLock {
                if (turnGeneration == prep.generation) activeAnswer = null
                prep.dedupeReservation?.let(suppressor::release)
                log(ConversationEvent.Failed(error, clock()))
            } else {
                mutex.withLock { prep.dedupeReservation?.let(suppressor::release) }
            }
            Turn(
                transcript = prep.transcript,
                question = reportedQuestion,
                suppressed = SuppressionReason.PROVIDER_ERROR,
                error = error,
                providerLatencyMillis = latencyMillis,
                answerTier = prep.tier,
                dedupeReservation = prep.dedupeReservation,
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
        const val MAX_CONCURRENT_BATCH_ANSWERS = 2

        /** Confidence stamped on a recent-context fallback candidate (last line, not a detected question). */
        const val RECENT_CONTEXT_FALLBACK_CONFIDENCE = 0.1

        /** Memory line used instead of a fabricated question for recent-context answers. */
        const val RECENT_CONTEXT_MEMORY_LABEL = "(asked from recent context)"
    }
}
