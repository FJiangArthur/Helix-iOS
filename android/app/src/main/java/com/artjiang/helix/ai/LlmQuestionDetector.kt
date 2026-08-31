package com.artjiang.helix.ai

import com.artjiang.helix.core.QuestionCandidate
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/** User-controlled recall/precision tradeoff for live question pickup. */
enum class QuestionSensitivity(
    internal val minimumHeuristicConfidence: Double,
    internal val skipLlmConfidence: Double,
    internal val promptInstruction: String,
) {
    PRECISE(
        minimumHeuristicConfidence = QuestionDetector.PUNCTUATION_CONFIDENCE,
        skipLlmConfidence = QuestionDetector.PUNCTUATION_CONFIDENCE,
        promptInstruction =
            "Precise sensitivity: return only an explicit direct question; reject statements, rhetorical phrasing, and vague requests.",
    ),
    BALANCED(
        minimumHeuristicConfidence = QuestionDetector.A_NOT_A_CONFIDENCE,
        skipLlmConfidence = QuestionDetector.PUNCTUATION_CONFIDENCE,
        promptInstruction =
            "Balanced sensitivity: return clear questions and direct spoken requests, including questions without punctuation.",
    ),
    HIGH(
        minimumHeuristicConfidence = QuestionDetector.A_NOT_A_CONFIDENCE,
        // Always consult the classifier: this level deliberately favors recall.
        skipLlmConfidence = 1.01,
        promptInstruction =
            "High sensitivity: include likely implied questions and requests when the speaker appears to expect an answer.",
    ),
}

/**
 * LLM-backed question detector for FINAL transcript segments.
 *
 * [QuestionDetector] is a cheap, local heuristic: it only catches a fixed set
 * of surface patterns (a literal "?", an English interrogative in first
 * position, a fixed list of Chinese particles/interrogatives). Real spoken
 * Chinese routinely produces none of those — e.g. the A-not-A construction
 * (有没有别的办法) or `几楼` (not in any fixed list) — so the heuristic alone
 * misses a large fraction of real questions. This class asks a fast/cheap
 * model to classify the segment instead, and returns EVERY question it finds
 * (not just the first), matching what a human listener would notice.
 *
 * This class takes its model call as a constructor-injected suspend function
 * rather than constructing a provider itself, so tests can inject a fake with
 * no network, no [ProviderFactory], and no [AnswerProvider]/[AnswerRequest]
 * machinery. The production wiring binds this to
 * `ProviderFactory.makeFast(settings).classify(prompt)` —
 * [AnswerProvider.classify] is a small dedicated method that sends the
 * classification prompt as-is (no [PromptBuilder] persona wrapping, tiny
 * token budget), kept separate from [AnswerProvider.answer].
 *
 * Cost control (this runs continuously on an 8-hour always-on session):
 *  - Callers MUST only invoke [detectQuestions] on a FINAL transcript segment,
 *    never a streaming partial. This class does not enforce that itself (it
 *    has no notion of partial/final) — see [ConversationEngine], which only
 *    calls it from the live-transcript path, which only ever receives finals.
 *  - The [classify] closure is expected to be bound to the FAST tier
 *    ([ProviderFactory.makeFast]) with a tiny token budget — this class asks
 *    for a compact list, not prose, so a small budget is sufficient.
 *  - [preFilter] lets one confident heuristic hit in a single-sentence
 *    utterance skip the LLM call entirely. A confident explicit question in
 *    one sentence must not hide an implicit question in a second sentence,
 *    so mixed/multi-sentence utterances are still classified and merged.
 *  - On any failure from [classify] (network error, malformed response, or an
 *    exception thrown by the closure) this falls back to the heuristic
 *    result rather than returning nothing — a broken network must not make
 *    detection go silent.
 *
 * No `android.*` imports (ai/ package rule) and no raw transcript content is
 * ever logged by this class.
 */
class LlmQuestionDetector(
    private val classify: suspend (String) -> String,
    private val heuristic: QuestionDetector = QuestionDetector(),
    /** Read per finalized segment so a Settings change applies without restart. */
    private val sensitivity: () -> QuestionSensitivity = { QuestionSensitivity.BALANCED },
) {

    /**
     * Returns every question found in [transcript] in spoken/source order.
     * Confidence still describes each candidate, but must never reorder the
     * conversation. Empty when none are found. Never throws — a classify
     * failure falls back to the heuristic result instead of propagating.
     */
    suspend fun detectQuestions(transcript: String): List<QuestionCandidate> {
        val trimmed = transcript.trim()
        if (trimmed.isEmpty()) return emptyList()

        val level = sensitivity()
        val heuristicHits = heuristic.detectQuestions(trimmed)
            .filter { it.confidence >= level.minimumHeuristicConfidence }
        val isSingleSentence = heuristic.splitSentences(trimmed).size == 1
        if (
            isSingleSentence &&
            heuristicHits.size == 1 &&
            heuristicHits.single().confidence >= level.skipLlmConfidence
        ) {
            // Pre-filter only a genuinely single-question utterance. In a
            // mixed block such as "What changed? I wonder who approved it",
            // the explicit first sentence is not evidence that the classifier
            // has nothing left to find in the rest of the block.
            return inSpokenOrder(trimmed, heuristicHits)
        }

        val llmHits = runCatching { classify(classifierPrompt(trimmed, level)) }
            .map { parseResponse(it, trimmed) }
            .getOrNull()

        // Network failure, malformed response, or classify() throwing all land
        // here as null: fall back to the heuristic rather than going silent.
        if (llmHits == null) {
            return inSpokenOrder(trimmed, heuristicHits)
        }

        // Merge: the LLM may confirm or add to what the heuristic found. De-dup
        // by normalized text so the same question isn't reported twice.
        val merged = LinkedHashMap<String, QuestionCandidate>()
        for (candidate in llmHits + heuristicHits) {
            val key = candidate.text.trim().lowercase()
            val existing = merged[key]
            if (existing == null || candidate.confidence > existing.confidence) {
                merged[key] = candidate
            }
        }
        return inSpokenOrder(trimmed, merged.values.toList())
    }

    /**
     * A later explicit `?` hit often has higher confidence than an earlier
     * statement-form question. Provider requests, chat rows, and the numbered
     * HUD must follow the speech, not that score. The original merged index is
     * an explicit stable tie-break for overlapping/equal-offset substrings.
     */
    private fun inSpokenOrder(
        transcript: String,
        candidates: List<QuestionCandidate>,
    ): List<QuestionCandidate> = candidates.withIndex()
        .sortedWith(
            compareBy<IndexedValue<QuestionCandidate>> {
                transcript.indexOf(it.value.text.trim(), ignoreCase = true)
                    .takeIf { offset -> offset >= 0 } ?: Int.MAX_VALUE
            }.thenBy { it.index },
        )
        .map { it.value }

    /**
     * Strict compact contract: a JSON array of exact transcript substrings.
     * Arbitrary model prose, headings, numbered explanations and object-shaped
     * JSON are rejected as zero candidates rather than becoming fake questions.
     */
    private fun parseResponse(raw: String, transcript: String): List<QuestionCandidate> {
        val body = raw.trim()
        if (body.isEmpty()) return emptyList()
        val array = runCatching { Json.parseToJsonElement(body) }.getOrNull() as? JsonArray
            ?: return emptyList()
        return array.mapNotNull { element ->
            val text = (element as? JsonPrimitive)?.contentOrNull?.trim().orEmpty()
            text.takeIf {
                it.length in 2..MAX_CLASSIFIED_QUESTION_LENGTH &&
                    transcript.contains(it, ignoreCase = true)
            }?.let { QuestionCandidate(it, LLM_CONFIDENCE) }
        }.distinctBy { it.text.lowercase() }
    }

    companion object {
        /** Confidence stamped on a question the LLM (not the heuristic) found. */
        const val LLM_CONFIDENCE = 0.85

        /** Sentinel the classifier prompt asks for when it finds no question. */
        const val NONE_MARKER = "[]"
        private const val MAX_CLASSIFIED_QUESTION_LENGTH = 280

        /**
         * Prompt for the FAST-tier classification call. Deliberately terse:
         * the model must return a compact list (or [NONE_MARKER]), never
         * prose, to keep the completion small and cheap.
         */
        fun classifierPrompt(
            transcript: String,
            sensitivity: QuestionSensitivity = QuestionSensitivity.BALANCED,
        ): String = buildString {
            append(
                "You are a question-detection classifier for live speech (any language, " +
                "including unpunctuated Chinese). Return only a compact JSON array of strings, " +
                    "with every question exactly as spoken (do not translate or rephrase). " +
                    "No headings, numbering, markdown, or explanation. " +
                    "If there are no questions, reply with exactly: $NONE_MARKER\n\n",
            )
            append(sensitivity.promptInstruction)
            append(
                "\nMultilingual question examples: English: Can you review this; " +
                    "中文: 你能帮我看一下; Español: ¿Puedes revisar esto?\n\n",
            )
            append("Speech: ")
            append(transcript)
        }
    }
}
