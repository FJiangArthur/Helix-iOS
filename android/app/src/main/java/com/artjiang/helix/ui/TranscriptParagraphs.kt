package com.artjiang.helix.ui

import com.artjiang.helix.ai.QuestionDetector

/**
 * Groups one long transcript entry into short paragraphs for readability,
 * WITHOUT implying separate speaker turns.
 *
 * Background: a live-transcribing model (e.g. `gpt-live-transcribe`) manages
 * turns natively and can emit a single multi-minute final segment with no
 * speaker labels. [com.artjiang.helix.HelixBridge] appends exactly one feed
 * entry per final, so that one segment renders as one enormous undifferentiated
 * block of text. Splitting it into multiple feed entries (multiple bubbles)
 * would fabricate turn boundaries the source never provided — worse than one
 * honest block, because a reader would believe real turn-taking occurred.
 *
 * Instead, this groups the SAME text into paragraphs meant to be rendered
 * inside a SINGLE bubble with extra vertical spacing between them.
 *
 * Strategy:
 *  1. Split into sentences with [QuestionDetector.splitSentences] (locale-aware
 *     `BreakIterator`, keeps terminal punctuation, already handles CJK
 *     terminators like `。！？`).
 *  2. Group a few sentences per paragraph, targeting [targetParagraphChars].
 *  3. If sentence splitting produced essentially one giant "sentence" (common
 *     for unpunctuated Chinese, where `BreakIterator` finds no boundaries),
 *     sentence-grouping alone is a no-op. Fall back to slicing that oversized
 *     chunk on a character budget, preferring a whitespace/CJK-punctuation
 *     boundary near the cut point so we don't sever mid-word/mid-character
 *     unnecessarily.
 *
 * No character of the input (other than whitespace normalization at
 * boundaries) is lost or duplicated: joining the result with any whitespace
 * and stripping all whitespace reproduces the whitespace-stripped input.
 */

/** Target size (in characters) for a single rendered paragraph. */
internal const val TARGET_PARAGRAPH_CHARS = 220

/** Sentence-grouping threshold: start a new paragraph once this size is reached. */
private const val SENTENCE_GROUP_CHARS = TARGET_PARAGRAPH_CHARS

/**
 * Hard budget for a single chunk before the unpunctuated-CJK character-budget
 * fallback kicks in. If sentence splitting yields any single "sentence" longer
 * than this, that sentence is further sliced on a character budget.
 */
private const val CHAR_BUDGET = 200

private val questionDetector = QuestionDetector()

/** Characters that make a reasonable break point when slicing raw text. */
private val SOFT_BREAK_CHARS = setOf(
    ' ', '\t', '\n',
    '，', ',', '、', '；', ';', '：', ':',
    '。', '！', '？', '.', '!', '?',
)

/**
 * Splits [transcript] into short paragraphs for display inside one bubble.
 *
 * Pure function: no Android/Compose imports, JVM-testable.
 */
internal fun paragraphsForTranscript(transcript: String): List<String> {
    if (transcript.isBlank()) return emptyList()

    val sentences = questionDetector.splitSentences(transcript)
        .map { it.trim() }
        .filter { it.isNotEmpty() }

    if (sentences.isEmpty()) return emptyList()

    // Expand any oversized "sentence" (e.g. one giant unpunctuated CJK run)
    // into character-budget-sized pieces before grouping. This is the path
    // that fires for unpunctuated Chinese: BreakIterator finds no sentence
    // boundaries, so `sentences` is a single entry the size of the whole
    // transcript, and sliceOnCharBudget breaks it up.
    val pieces = sentences.flatMap { sentence ->
        if (sentence.length > CHAR_BUDGET) sliceOnCharBudget(sentence, CHAR_BUDGET) else listOf(sentence)
    }

    // Group consecutive pieces into paragraphs up to the target size.
    val paragraphs = mutableListOf<String>()
    val current = StringBuilder()
    for (piece in pieces) {
        if (current.isNotEmpty() && current.length + 1 + piece.length > SENTENCE_GROUP_CHARS) {
            paragraphs += current.toString()
            current.clear()
        }
        if (current.isNotEmpty()) current.append(' ')
        current.append(piece)
    }
    if (current.isNotEmpty()) paragraphs += current.toString()

    return paragraphs
}

/**
 * Slices [text] into pieces of at most [budget] characters, preferring to cut
 * at the last soft-break character within the budget window so words/clauses
 * aren't severed unnecessarily. Falls back to a hard cut at [budget] if no
 * soft break is found. No characters are dropped.
 */
private fun sliceOnCharBudget(text: String, budget: Int): List<String> {
    if (text.length <= budget) return listOf(text)

    val result = mutableListOf<String>()
    var start = 0
    val minChunk = budget / 2
    while (start < text.length) {
        val hardEnd = minOf(start + budget, text.length)
        if (hardEnd == text.length) {
            result += text.substring(start, hardEnd)
            break
        }
        // Search backwards from hardEnd for a soft break, but don't accept
        // one so early that the chunk becomes tiny.
        var cut = hardEnd
        var searchIndex = hardEnd - 1
        while (searchIndex > start + minChunk) {
            if (text[searchIndex] in SOFT_BREAK_CHARS) {
                cut = searchIndex + 1
                break
            }
            searchIndex--
        }
        result += text.substring(start, cut)
        start = cut
    }
    return result
}
