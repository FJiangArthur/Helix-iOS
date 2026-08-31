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
                hasChineseANotAConstruction(trimmed) -> QuestionCandidate(trimmed, A_NOT_A_CONFIDENCE)
                else -> null
            }
        }

    fun isQuestion(sentence: String): Boolean {
        val trimmed = sentence.trim()
        if (trimmed.isEmpty()) return false
        return endsWithQuestionMark(trimmed) ||
            hasQuestionPrefix(trimmed) ||
            hasChineseQuestionParticle(trimmed) ||
            hasChineseANotAConstruction(trimmed)
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
        // MID-STRING, not just endsWith: real speech tacks a clause onto the
        // end of an already-asked question ("这个方案可行吗我们下周定" — the
        // particle "吗" sits mid-string, not at the end), and a strict
        // endsWith check missed every one of those.
        if (CHINESE_TAIL_PARTICLES.any { stripped.contains(it) }) return true
        return CHINESE_INTERROGATIVES.any { sentence.contains(it) }
    }

    /**
     * A-not-A construction (正反问句): "X不X" / "X沒X", e.g. 有没有, 是不是,
     * 能不能, 可不可以, 对不对. This is the single most common spoken Chinese
     * interrogative form and was previously entirely absent from the rules —
     * "有没有别的办法" (do you have another way) has no "?", no particle, and
     * no listed interrogative word, so it was missed outright.
     */
    private fun hasChineseANotAConstruction(sentence: String): Boolean =
        A_NOT_A_PHRASES.any { sentence.contains(it) }

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
            // Previously missing: "会议室在几楼" (几楼, not 几点) was missed
            // outright because only "几点" was listed.
            "哪个", "哪個", "什么时候", "什麼時候", "怎样", "怎樣",
            "几楼", "幾樓", "几个", "幾個", "几号", "幾號", "几月", "幾月",
            "几天", "幾天", "几年", "幾年", "几次", "幾次",
        )

        /**
         * Given a lower confidence than [PREFIX_CONFIDENCE]: the A-not-A form is
         * a strong signal on its own, but a bare substring match (e.g. "有没有")
         * can in principle appear inside a longer non-interrogative clause, so
         * it is scored below the more specific particle/prefix rules to keep
         * the score meaningful.
         */
        const val A_NOT_A_CONFIDENCE = 0.60

        /**
         * "X不X" / "X沒X" literal forms for the verbs/adjectives spoken Chinese
         * actually uses this way: 有没有, 是不是, 能不能, 可不可以, 对不对,
         * 要不要, 会不会, 好不好, 行不行. A closed literal list rather than a
         * generic `.不.` pattern, which would also match unrelated text like a
         * name that happens to contain "不".
         */
        private val A_NOT_A_PHRASES = listOf(
            "有没有", "有沒有", "是不是", "能不能", "可不可以",
            "对不对", "對不對", "要不要", "会不会", "會不會", "好不好", "行不行",
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
class DuplicateQuestionSuppressor(
    private val locale: Locale = Locale.ROOT,
    /**
     * How long a question stays "already asked".
     *
     * Unbounded suppression was a real defect: `seen` was never cleared for the
     * process lifetime, so the second time a question was asked — even an hour
     * later — it was silently dropped and no answer ever reached the feed.
     */
    private val windowMillis: Long = DEFAULT_WINDOW_MILLIS,
    private val maxEntries: Int = DEFAULT_MAX_ENTRIES,
    private val clock: () -> Long = System::currentTimeMillis,
) {

    /** One in-flight claim. Its token prevents a stale failure from releasing a newer claim. */
    class Reservation internal constructor(internal val key: String, internal val token: Long)

    /** Normalization key -> when it was last seen. Insertion-ordered for eviction. */
    private val seen = LinkedHashMap<String, Long>()
    private val reservations = mutableMapOf<String, Long>()
    private var nextReservationToken = 0L

    /** Filters out candidates already seen inside the window. */
    fun uniqueQuestions(candidates: List<QuestionCandidate>): List<QuestionCandidate> =
        candidates.filter { markIfNew(it.text) }

    /** @return true when [question] has not been seen recently (and records it). */
    fun markIfNew(question: String): Boolean {
        val reservation = reserveIfAvailable(question) ?: return false
        commit(reservation)
        return true
    }

    /**
     * Claims a question while its provider is in flight without stamping the
     * ten-minute answered window yet. The caller must [commit] only after the
     * answer becomes publishable, or [release] on failure/cancellation.
     */
    fun reserveIfAvailable(question: String): Reservation? {
        val key = normalizationKey(question)
        if (key.isEmpty()) return null
        evict(clock())
        if (key in seen || key in reservations) return null
        val token = ++nextReservationToken
        reservations[key] = token
        return Reservation(key, token)
    }

    fun commit(reservation: Reservation): Boolean {
        if (reservations[reservation.key] != reservation.token) return false
        reservations.remove(reservation.key)
        // Stamp completion time, not detection time. A failed/slow request
        // must not consume the retry window.
        seen[reservation.key] = clock()
        evict(clock())
        return true
    }

    fun release(reservation: Reservation): Boolean {
        if (reservations[reservation.key] != reservation.token) return false
        reservations.remove(reservation.key)
        return true
    }

    fun hasSeen(question: String): Boolean {
        val key = normalizationKey(question)
        if (key.isEmpty()) return false
        evict(clock())
        return key in seen || key in reservations
    }

    fun reset() {
        seen.clear()
        reservations.clear()
    }

    fun normalizationKey(question: String): String = buildString {
        for (ch in question.lowercase(locale)) {
            if (ch.isWhitespace()) continue
            // Keep letters and digits of any script; drop punctuation and symbols.
            if (ch.isLetterOrDigit()) append(ch)
        }
    }

    /** Drops keys older than the window, then any excess over the cap (oldest first). */
    private fun evict(now: Long) {
        val cutoff = now - windowMillis
        val stale = seen.entries.filter { it.value < cutoff }.map { it.key }
        stale.forEach { seen.remove(it) }
        while (seen.size > maxEntries) {
            val oldest = seen.entries.firstOrNull()?.key ?: break
            seen.remove(oldest)
        }
    }

    companion object {
        /** 10 minutes: long enough to stop stutter-repeats, short enough that a
         *  genuinely re-asked question later in a conversation is answered. */
        const val DEFAULT_WINDOW_MILLIS = 600_000L

        /** Hard cap so an 8-hour session cannot grow the map without bound. */
        const val DEFAULT_MAX_ENTRIES = 200
    }
}
