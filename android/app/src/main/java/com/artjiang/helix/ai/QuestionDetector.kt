package com.artjiang.helix.ai

import com.artjiang.helix.core.QuestionCandidate
import java.text.BreakIterator
import java.util.Locale

/**
 * Detects questions in a transcript segment.
 *
 * Fixes two bugs in the Swift original ([QuestionDetector] in SpeechServices.swift):
 *  1. It split on `.?!` with `split(whereSeparator:)`, which *removed* the terminal
 *     punctuation — so the very next check, `hasSuffix("?")`, could never be true.
 *     Every question fell through to the prefix heuristic at 0.72, and any
 *     non-English question with no interrogative prefix was missed entirely.
 *  2. It only knew ASCII sentence terminators, so CJK text (。！？) was never split
 *     and full-width `？` was never recognized.
 *
 * Here sentence splitting uses [BreakIterator], which is locale-aware and handles
 * CJK terminators, and the terminal punctuation is preserved.
 */
class QuestionDetector(private val locale: Locale = Locale.ROOT) {

    fun detectQuestions(transcript: String): List<QuestionCandidate> =
        splitSentences(transcript).mapNotNull { sentence ->
            val trimmed = sentence.trim()
            when {
                trimmed.isEmpty() -> null
                endsWithQuestionMark(trimmed) -> QuestionCandidate(trimmed, PUNCTUATION_CONFIDENCE)
                hasQuestionPrefix(trimmed) -> QuestionCandidate(trimmed, PREFIX_CONFIDENCE)
                hasChineseQuestionParticle(trimmed) -> QuestionCandidate(trimmed, PREFIX_CONFIDENCE)
                else -> null
            }
        }

    fun isQuestion(sentence: String): Boolean {
        val trimmed = sentence.trim()
        if (trimmed.isEmpty()) return false
        return endsWithQuestionMark(trimmed) ||
            hasQuestionPrefix(trimmed) ||
            hasChineseQuestionParticle(trimmed)
    }

    /** Locale-aware sentence segmentation that KEEPS terminal punctuation. */
    internal fun splitSentences(transcript: String): List<String> {
        if (transcript.isBlank()) return emptyList()
        val iterator = BreakIterator.getSentenceInstance(locale)
        iterator.setText(transcript)

        val sentences = mutableListOf<String>()
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            val piece = transcript.substring(start, end).trim()
            if (piece.isNotEmpty()) sentences += piece
            start = end
            end = iterator.next()
        }
        return sentences
    }

    private fun endsWithQuestionMark(sentence: String): Boolean {
        // Ignore trailing quotes/brackets so `He asked "Ready?"` still counts.
        val trailing = sentence.trimEnd(*TRAILING_TRIM)
        val last = trailing.lastOrNull() ?: return false
        return last in QUESTION_MARKS
    }

    private fun hasQuestionPrefix(sentence: String): Boolean {
        val lowered = sentence.lowercase(locale).trimStart(*LEADING_TRIM)
        val firstWord = lowered.takeWhile { !it.isWhitespace() }.trim(*TRAILING_TRIM)
        if (firstWord.isEmpty()) return false
        return firstWord in ENGLISH_QUESTION_PREFIXES
    }

    private fun hasChineseQuestionParticle(sentence: String): Boolean {
        val stripped = sentence.trimEnd(*TRAILING_TRIM)
        if (CHINESE_TAIL_PARTICLES.any { stripped.endsWith(it) }) return true
        return CHINESE_INTERROGATIVES.any { sentence.contains(it) }
    }

    companion object {
        const val PUNCTUATION_CONFIDENCE = 0.95
        const val PREFIX_CONFIDENCE = 0.72

        /** ASCII `?`, full-width `？`, and the Arabic question mark. */
        private val QUESTION_MARKS = setOf('?', '？', '؟')

        private val TRAILING_TRIM = charArrayOf(
            ' ', '\t', '\n', '"', '\'', '”', '’', ')', ']', '}', '»', '」', '』', '）', '.', '。',
        )
        private val LEADING_TRIM = charArrayOf(
            ' ', '\t', '\n', '"', '\'', '“', '‘', '(', '[', '{', '«', '「', '『', '（', '-', '—',
        )

        private val ENGLISH_QUESTION_PREFIXES = setOf(
            "what", "why", "how", "when", "where", "who", "whom", "whose", "which",
            "can", "could", "should", "would", "will", "shall", "is", "are", "was",
            "were", "do", "does", "did", "am", "may", "might", "have", "has", "had",
        )

        /** Sentence-final interrogative particles. */
        private val CHINESE_TAIL_PARTICLES = listOf("吗", "嗎", "呢", "吧")

        /** Interrogative words that make a Chinese sentence a question without a particle. */
        private val CHINESE_INTERROGATIVES = listOf(
            "什么", "什麼", "怎么", "怎麼", "为什么", "為什麼", "哪里", "哪裡", "哪儿",
            "谁", "誰", "多少", "几点", "幾點", "如何", "是否",
        )
    }
}

/**
 * Suppresses repeats of the same question.
 *
 * The Swift original normalized with the regex `[^a-z0-9 ]`, which deletes every
 * CJK character — so "你叫什么名字？" and "你今年多大？" both normalize to the empty
 * string and the second one is wrongly suppressed. Here normalization only
 * lowercases and strips whitespace and punctuation, so CJK content survives.
 */
class DuplicateQuestionSuppressor(private val locale: Locale = Locale.ROOT) {

    private val seen = LinkedHashSet<String>()

    /** Filters out candidates already seen in this session. */
    fun uniqueQuestions(candidates: List<QuestionCandidate>): List<QuestionCandidate> =
        candidates.filter { markIfNew(it.text) }

    /** @return true when [question] has not been seen before (and records it). */
    fun markIfNew(question: String): Boolean {
        val key = normalizationKey(question)
        if (key.isEmpty()) return false
        return seen.add(key)
    }

    fun hasSeen(question: String): Boolean = normalizationKey(question) in seen

    fun reset() = seen.clear()

    fun normalizationKey(question: String): String = buildString {
        for (ch in question.lowercase(locale)) {
            if (ch.isWhitespace()) continue
            // Keep letters and digits of any script; drop punctuation and symbols.
            if (ch.isLetterOrDigit()) append(ch)
        }
    }
}
