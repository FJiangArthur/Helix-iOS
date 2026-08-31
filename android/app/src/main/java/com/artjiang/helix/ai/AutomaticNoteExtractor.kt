package com.artjiang.helix.ai

import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.core.QuestionCandidate
import com.artjiang.helix.core.TranscriptSegment
import java.text.Normalizer
import java.util.Locale

/** High-confidence categories that Helix may save without an extra tap. */
enum class AutomaticNoteKind(val sourceLabel: String) {
    FACT("Fact"),
    DECISION("Decision"),
    ACTION_ITEM("Action item"),
    ANSWER("Answer"),
}

data class AutomaticNoteCandidate(
    val kind: AutomaticNoteKind,
    val bucket: KnowledgeBucket,
    val text: String,
)

private data class EmbeddingGovernor(
    val present: Boolean,
    val allowsArbitraryAuxiliarySubject: Boolean,
)

/**
 * Conservative, local auto-note extraction for finalized speech.
 *
 * This deliberately prefers missing a note over saving ordinary chatter. Only
 * explicit decisions, commitments/action-item labels, and a small set of
 * useful fact forms qualify. Questions and credential-like content are never
 * captured. No network classifier is involved, so note capture cannot delay
 * question answering or silently send transcript text to another service.
 */
object AutomaticNoteExtractor {
    private val sentencePattern = Regex("[^.!?。！？\u061F\\n]+[.!?。！？\u061F]?")
    private val localQuestionDetector = QuestionDetector()

    private val decisionPatterns = listOf(
        Regex("^(?:i|we|the team)\\s+(?:decided|agreed|chose|confirmed|settled on)\\b", RegexOption.IGNORE_CASE),
        Regex("^(?:decision|decision made)\\s*[:\\-]", RegexOption.IGNORE_CASE),
    )
    private val actionPatterns = listOf(
        Regex("^(?:action item|todo|to-do)\\s*[:\\-]", RegexOption.IGNORE_CASE),
        Regex(
            "^(?:i|we|you|[\\p{L}][\\p{L}'-]{1,30})\\s+" +
                "(?:need(?:s)? to|must|will|should|have to|has to|am going to|are going to|is going to)\\b",
            RegexOption.IGNORE_CASE,
        ),
    )
    private val factPatterns = listOf(
        Regex("^(?:remember|note)\\s+(?:that\\s+)?", RegexOption.IGNORE_CASE),
        Regex(
            "^(?:my|our)\\s+(?:email|phone|address|timezone|birthday|preference|favorite|" +
                "deadline|meeting|appointment|launch|release|reservation|flight|project)\\b.{0,50}" +
                "\\b(?:is|are|starts|ends|moved to|has moved to|has been moved to)\\b",
            RegexOption.IGNORE_CASE,
        ),
        Regex(
            "^(?:the|our)\\s+(?:deadline|meeting|appointment|launch|release|reservation|flight)\\b.{0,50}" +
                "\\b(?:is|are|starts|ends|moved to|has moved to|has been moved to)\\b",
            RegexOption.IGNORE_CASE,
        ),
    )
    /**
     * Speech recognizers often omit terminal punctuation. Catch the common
     * fact-shaped question form that can otherwise satisfy [factPatterns]
     * before an on-demand user taps Ask Now (for example, "My deadline is what
     * day"). The policy is intentionally conservative: ambiguous spans are
     * skipped instead of being written to Knowledge.
     */
    private val confirmationQuestionPattern = Regex(
        "(?:[,，]\\s*)?(?:" +
            "(?:is|are|was|were|do|does|did|can|could|would|should|will|has|have|" +
            "isn['’]?t|aren['’]?t|wasn['’]?t|weren['’]?t|don['’]?t|doesn['’]?t|" +
            "didn['’]?t|can['’]?t|couldn['’]?t|wouldn['’]?t|shouldn['’]?t|won['’]?t|" +
            "hasn['’]?t|haven['’]?t)\\s+(?:i|you|he|she|it|we|they|there)|" +
            "right|correct|yes\\s+or\\s+no" +
            ")(?:\\s+(?:though|really|exactly))?\\s*[.!。！]*$",
        RegexOption.IGNORE_CASE,
    )
    private val terminalWhQuestionPattern = Regex(
        "\\b(?:what|which|when|where|who|whom|whose|why|how)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val whTailTokenPattern = Regex("[\\p{L}\\p{M}\\p{N}'’]+")
    private val clauseAuxiliaries = setOf(
        "am", "is", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "have", "has", "had", "can", "could",
        "will", "would", "should", "shall", "may", "might", "must",
    )
    private val clauseSubjectPronouns = setOf(
        "i", "we", "you", "he", "she", "it", "they", "there",
    )
    private val clauseDeterminers = setOf(
        "the", "a", "an", "my", "our", "your", "his", "her", "its", "their",
        "this", "that", "these", "those",
    )
    private val clauseSelectorNouns = setOf(
        "day", "date", "time", "room", "airport", "offset", "people", "person",
        "name", "number", "option", "route", "timezone", "location", "place",
    )
    private val embeddingGovernorWords = setOf(
        "remember", "note", "decide", "decided", "agree", "agreed", "choose", "chose",
        "confirm", "confirmed", "explain", "explains", "explained", "document", "documents",
        "documented", "describe", "describes", "described", "know", "knows", "knew",
        "understand", "understands", "show", "shows", "tell", "tells", "discuss",
        "discusses", "determine", "determines", "determined", "schedule", "scheduled",
    )
    private val actionGovernorPredecessors = setOf(
        "to", "will", "must", "should", "can", "could", "would", "shall", "may", "might",
    )
    private val sensitivePattern = Regex(
        "\\b(?:password|passcode|pin|secret|ssn|cvv|api[\\s_\\p{Pd}]*key|" +
            "private[\\s_\\p{Pd}]*key|seed[\\s_\\p{Pd}]*phrase|social[\\s_\\p{Pd}]*security|" +
            "credit[\\s_\\p{Pd}]*card|card[\\s_\\p{Pd}]*number|" +
            "(?:access|auth(?:entication|orization)?|bearer|oauth(?:[\\s_\\p{Pd}]*2(?:\\.0)?)?|refresh|session)" +
            "[\\s_\\p{Pd}]*tokens?|recovery[\\s_\\p{Pd}]*codes?)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val bearerCredentialPattern = Regex(
        "\\b(?:authorization\\s*[:=]?\\s*)?bearer\\s+(?!tokens?\\b)[A-Za-z0-9._~+/=-]{12,}",
        RegexOption.IGNORE_CASE,
    )
    private val jwtCredentialPattern = Regex(
        "(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{16,}(?![A-Za-z0-9_-])",
    )
    private val uncertainAnswerPattern = Regex(
        "\\b(?:i (?:do not|don't) know|i(?:'m| am) not sure|cannot verify|can't verify|" +
            "uncertain|unknown|insufficient (?:information|context)|unable to (?:answer|determine)|" +
            "question (?:was|got|seems? to be) (?:cut off|incomplete)|" +
            "(?:could|can|would) you (?:please )?(?:repeat|rephrase|clarify|provide)|" +
            "please (?:repeat|rephrase|clarify)|(?:not enough|need more) (?:information|context))\\b",
        RegexOption.IGNORE_CASE,
    )
    private val answerInversionQuestionPattern = Regex(
        "^(?:(?:can|could|should|would|will|do|does|did|is|are|was|were|has|have|had)\\s+" +
            "(?:i|you|we|they|he|she|it|there)|" +
            "(?:what|why|how|when|where|who|which)\\s+" +
            "(?:am|is|are|was|were|do|does|did|have|has|had|can|could|will|would|should|must))\\b",
        RegexOption.IGNORE_CASE,
    )

    fun extract(
        segment: TranscriptSegment,
        excludedQuestionTexts: Collection<String> = emptyList(),
    ): List<AutomaticNoteCandidate> {
        if (!segment.isFinal) return emptyList()
        // Credential formats such as JWTs contain sentence punctuation. Check
        // the intact final before splitting so no individually benign-looking
        // token fragment can be persisted as a note.
        if (containsSensitiveContent(segment.text)) return emptyList()
        val excludedQuestions = excludedQuestionTexts
            .map(::normalized)
            .filter(String::isNotEmpty)
        return sentencePattern.findAll(segment.text)
            .map { it.value.trim().replace(Regex("\\s+"), " ") }
            .filter { sentence ->
                sentence.length in MIN_LENGTH..MAX_LENGTH &&
                    !localQuestionDetector.isQuestion(sentence) &&
                    !confirmationQuestionPattern.containsMatchIn(sentence) &&
                    !containsSensitiveContent(sentence) &&
                    excludedQuestions.none { question -> sameSemanticSpan(sentence, question) }
            }
            .mapNotNull(::classify)
            .filter { candidate -> !isTerminalWhQuestion(candidate.text, candidate.kind) }
            .distinctBy { candidate -> candidate.bucket to normalized(candidate.text) }
            .take(MAX_NOTES_PER_SEGMENT)
            .toList()
    }

    /**
     * Conservative capture of a completed high-confidence Q&A. This is local
     * and synchronous; the repository write is launched separately by the
     * bridge after answer publication, so note work never delays the answer.
     */
    fun extractAnswer(turn: Turn): AutomaticNoteCandidate? {
        val question = turn.question ?: return null
        val answer = turn.answer ?: return null
        if (turn.error != null || turn.suppressed != null) return null
        if (answer.providerKind == ProviderKind.DETERMINISTIC) return null
        if (question.confidence < MIN_ANSWER_QUESTION_CONFIDENCE) return null

        val questionText = question.text.trim().replace(Regex("\\s+"), " ")
        val answerText = answer.text.trim().replace(Regex("\\s+"), " ")
        if (questionText.length < MIN_ANSWER_QUESTION_LENGTH ||
            answerText.length !in MIN_ANSWER_LENGTH..MAX_ANSWER_LENGTH
        ) return null
        if (containsSensitiveContent(questionText) || containsSensitiveContent(answerText)) return null
        if (isQuestionShapedAnswer(answerText)) return null
        if (uncertainAnswerPattern.containsMatchIn(answerText)) return null

        return AutomaticNoteCandidate(
            kind = AutomaticNoteKind.ANSWER,
            bucket = KnowledgeBucket.FACTS,
            text = "Q: $questionText\nA: $answerText",
        )
    }

    private fun classify(sentence: String): AutomaticNoteCandidate? = when {
        decisionPatterns.any { it.containsMatchIn(sentence) } -> AutomaticNoteCandidate(
            AutomaticNoteKind.DECISION,
            KnowledgeBucket.MEMORIES,
            sentence,
        )
        actionPatterns.any { it.containsMatchIn(sentence) } -> AutomaticNoteCandidate(
            AutomaticNoteKind.ACTION_ITEM,
            KnowledgeBucket.TODOS,
            sentence,
        )
        factPatterns.any { it.containsMatchIn(sentence) } -> AutomaticNoteCandidate(
            AutomaticNoteKind.FACT,
            KnowledgeBucket.FACTS,
            sentence,
        )
        else -> null
    }

    private fun normalized(text: String): String = Normalizer.normalize(text, Normalizer.Form.NFKC)
        .lowercase(Locale.ROOT)
        .trim()
        .replace(Regex("\\s+"), " ")
        .trimEnd('.', '!', '?', '。', '！', '？', '\u061F')

    /**
     * LLM classification returns an exact transcript substring, while local
     * sentence extraction may retain adjacent punctuation or a short spoken
     * continuation. Treat either normalized containment direction as the same
     * span so a detected question can never leak into automatic Knowledge.
     */
    private fun sameSemanticSpan(sentence: String, normalizedQuestion: String): Boolean {
        val normalizedSentence = normalized(sentence)
        return normalizedSentence == normalizedQuestion ||
            containsAtSemanticBoundary(normalizedSentence, normalizedQuestion) ||
            containsAtSemanticBoundary(normalizedQuestion, normalizedSentence)
    }

    /**
     * Reject a trailing WH noun/fragment when the live classifier is absent,
     * while preserving embedded clauses such as "how the model works" and
     * "which gives us three days". This applies after note classification so
     * a bare fragment cannot leak through a decision or action prefix either.
     */
    private fun isTerminalWhQuestion(
        sentence: String,
        kind: AutomaticNoteKind,
    ): Boolean {
        val whMatch = terminalWhQuestionPattern.findAll(sentence).lastOrNull() ?: return false
        val tail = sentence.substring(whMatch.range.last + 1)
        val prefix = sentence.substring(0, whMatch.range.first).trimEnd()
        val followsClauseComma = prefix.endsWith(',') || prefix.endsWith('，')
        val governor = embeddingGovernor(prefix, kind)
        return !looksLikeEmbeddedWhClause(
            rawTail = tail,
            whWord = whMatch.value.lowercase(Locale.ROOT),
            followsClauseComma = followsClauseComma,
            governor = governor,
        )
    }

    private fun looksLikeEmbeddedWhClause(
        rawTail: String,
        whWord: String,
        followsClauseComma: Boolean,
        governor: EmbeddingGovernor,
    ): Boolean {
        val tokens = whTailTokenPattern.findAll(rawTail)
            .map { it.value.lowercase(Locale.ROOT).trim('\'', '’') }
            .filter(String::isNotEmpty)
            .toList()
        if (tokens.isEmpty()) return false

        val auxiliaryIndex = tokens.indexOfFirst { it in clauseAuxiliaries }
        val relativePronoun = whWord in setOf("which", "who", "whom", "whose")
        val directFiniteRelative = relativePronoun &&
            tokens.size >= 2 &&
            (tokens.first() in clauseAuxiliaries || looksLikeFiniteVerb(tokens.first()))
        if (followsClauseComma) return directFiniteRelative
        if (!governor.present) return false
        if (whWord == "how" && tokens.first() in setOf("many", "much")) return false
        if (tokens.first() in clauseSubjectPronouns && tokens.size >= 2) {
            val predicate = tokens[1]
            return predicate in clauseAuxiliaries ||
                looksLikeFiniteVerb(predicate) ||
                tokens.size >= 3
        }
        if (tokens.first() in clauseDeterminers) {
            if (auxiliaryIndex >= 1) return true
            if (tokens.size >= 3 && looksLikeFiniteVerb(tokens.last())) return true
        }
        if (auxiliaryIndex >= 1 && tokens.first() !in clauseSelectorNouns) return true
        if (looksLikeFiniteVerb(tokens.first())) return true
        if (tokens.size >= 2 && looksLikeFiniteVerb(tokens[1])) return true
        if (whWord in setOf("how", "when", "where", "why")) {
            if (auxiliaryIndex >= 1) return true
        }
        if (governor.allowsArbitraryAuxiliarySubject && auxiliaryIndex >= 0) return true
        return directFiniteRelative
    }

    private fun embeddingGovernor(
        prefix: String,
        kind: AutomaticNoteKind,
    ): EmbeddingGovernor {
        val tokens = whTailTokenPattern.findAll(prefix)
            .map { it.value.lowercase(Locale.ROOT).trim('\'', '’') }
            .filter(String::isNotEmpty)
            .toList()
        val last = tokens.lastOrNull() ?: return EmbeddingGovernor(false, false)
        if (last in embeddingGovernorWords || looksLikeFiniteVerb(last)) {
            return EmbeddingGovernor(true, true)
        }
        if (last in clauseAuxiliaries) return EmbeddingGovernor(true, false)
        val actionBaseVerbGovernor = kind == AutomaticNoteKind.ACTION_ITEM &&
            tokens.size >= 2 &&
            tokens[tokens.lastIndex - 1] in actionGovernorPredecessors
        return EmbeddingGovernor(actionBaseVerbGovernor, actionBaseVerbGovernor)
    }

    private fun looksLikeFiniteVerb(token: String): Boolean =
        token.length >= 4 &&
            (token.endsWith("s") || token.endsWith("ed") || token.endsWith("ing"))

    /**
     * Match a classifier substring only when it begins and ends at Unicode
     * word boundaries. Plain [String.contains] lets a short question such as
     * "Art?" match the `art` inside "starts", suppressing an unrelated fact.
     */
    private fun containsAtSemanticBoundary(haystack: String, needle: String): Boolean {
        if (needle.isEmpty()) return false
        var startIndex = haystack.indexOf(needle)
        while (startIndex >= 0) {
            val endIndex = startIndex + needle.length
            val startsAtBoundary = startIndex == 0 ||
                !isSemanticWordCodePoint(haystack.codePointBefore(startIndex))
            val endsAtBoundary = endIndex == haystack.length ||
                !isSemanticWordCodePoint(haystack.codePointAt(endIndex))
            if (startsAtBoundary && endsAtBoundary) return true
            startIndex = haystack.indexOf(needle, startIndex + 1)
        }
        return false
    }

    private fun isSemanticWordCodePoint(codePoint: Int): Boolean =
        Character.isLetterOrDigit(codePoint) ||
            when (Character.getType(codePoint)) {
                Character.NON_SPACING_MARK.toInt(),
                Character.COMBINING_SPACING_MARK.toInt(),
                Character.ENCLOSING_MARK.toInt(),
                Character.CONNECTOR_PUNCTUATION.toInt() -> true
                else -> false
            }

    private fun containsSensitiveContent(text: String): Boolean {
        val compatibilityNormalized = Normalizer.normalize(text, Normalizer.Form.NFKC)
        return sensitivePattern.containsMatchIn(compatibilityNormalized) ||
            bearerCredentialPattern.containsMatchIn(compatibilityNormalized) ||
            jwtCredentialPattern.containsMatchIn(compatibilityNormalized)
    }

    private fun isQuestionShapedAnswer(text: String): Boolean {
        val withoutClosers = text.trimEnd().trimEnd('"', '\'', '”', '’', '»', ')', ']', '}', '）', '」', '』')
        return withoutClosers.lastOrNull() in setOf('?', '？', '\u061F') ||
            answerInversionQuestionPattern.containsMatchIn(text.trimStart())
    }

    private const val MIN_LENGTH = 12
    private const val MAX_LENGTH = 280
    private const val MAX_NOTES_PER_SEGMENT = 3
    private const val MIN_ANSWER_QUESTION_CONFIDENCE = LlmQuestionDetector.LLM_CONFIDENCE
    private const val MIN_ANSWER_QUESTION_LENGTH = 8
    private const val MIN_ANSWER_LENGTH = 12
    private const val MAX_ANSWER_LENGTH = 600
}
