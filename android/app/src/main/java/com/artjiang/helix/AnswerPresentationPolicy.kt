package com.artjiang.helix

import com.artjiang.helix.core.QuestionCandidate

/** Routes one concurrent candidate to the single phone/HUD streaming preview. */
internal class CandidateStreamPreview(private val sink: (String) -> Unit) {
    private val lock = Any()
    private var owner: String? = null

    fun onStarted(candidate: QuestionCandidate) {
        synchronized(lock) {
            if (owner == null) owner = candidate.text
        }
    }

    fun onDelta(candidate: QuestionCandidate, chunk: String) {
        val accepted = synchronized(lock) { owner == candidate.text }
        if (accepted) sink(chunk)
    }
}

/** One completed answer before the whole finalized transcript is sent to the HUD. */
internal data class HudAnsweredTurn(
    val question: String?,
    val answer: String,
    val feedEntryId: Long?,
)

internal data class HudAnswerPresentation(
    val text: String,
    val ownerFeedEntryId: Long?,
    /** Every answer card whose content is contained in this one HUD payload. */
    val answerFeedEntryIds: Set<Long> = ownerFeedEntryId?.let(::setOf) ?: emptySet(),
)

/**
 * One finalized transcript owns one HUD lifecycle. Multiple answers are
 * combined so answer two cannot cancel answer one's 0x71 delivery/ACK owner.
 */
internal fun hudAnswerPresentation(turns: List<HudAnsweredTurn>): HudAnswerPresentation? {
    val useful = turns.mapNotNull { turn ->
        val answer = turn.answer.trim()
        if (answer.isEmpty()) null else turn.copy(answer = answer)
    }
    if (useful.isEmpty()) return null
    if (useful.size == 1) {
        val only = useful.single()
        return HudAnswerPresentation(only.answer, only.feedEntryId)
    }
    val text = useful.mapIndexed { index, turn ->
        val heading = turn.question?.trim().takeUnless { it.isNullOrEmpty() } ?: "Answer ${index + 1}"
        "${index + 1}. $heading\n${turn.answer}"
    }.joinToString("\n\n")
    // No individual card solely owns the combined transport acknowledgement,
    // but every included answer must render the shared delivery truth.
    return HudAnswerPresentation(
        text = text,
        ownerFeedEntryId = null,
        answerFeedEntryIds = useful.mapNotNullTo(LinkedHashSet()) { it.feedEntryId },
    )
}

internal inline fun presentHudAnswerBatch(
    turns: List<HudAnsweredTurn>,
    present: (HudAnswerPresentation) -> Unit,
) {
    hudAnswerPresentation(turns)?.let(present)
}

internal data class QuestionFeedAttribution(val speaker: String?, val isUser: Boolean)

/** Where an answered question came from, and whether it already has a feed row. */
internal enum class QuestionFeedOrigin {
    /** Speech/transcript text; preserve source attribution or remain unknown. */
    TRANSCRIPT,

    /** Text entered directly into the Assistant composer. */
    TYPED_USER,

    /** Think Deeper on an existing answer; the original question row already exists. */
    EXISTING_FEED,
}

internal data class QuestionFeedPlacement(
    val shouldAppend: Boolean,
    val attribution: QuestionFeedAttribution,
)

/** Substring questions cannot promote the whole transcript row; keep its author on the new row. */
internal fun questionFeedAttribution(source: FeedEntry?): QuestionFeedAttribution =
    QuestionFeedAttribution(speaker = source?.speaker, isUser = source?.isUser ?: false)

/** Pure policy so manual/deeper paths cannot silently drift back to transcript defaults. */
internal fun questionFeedPlacement(
    origin: QuestionFeedOrigin,
    source: FeedEntry?,
): QuestionFeedPlacement = when (origin) {
    QuestionFeedOrigin.TRANSCRIPT -> QuestionFeedPlacement(
        shouldAppend = true,
        attribution = questionFeedAttribution(source),
    )
    QuestionFeedOrigin.TYPED_USER -> QuestionFeedPlacement(
        shouldAppend = true,
        attribution = QuestionFeedAttribution(speaker = null, isUser = true),
    )
    QuestionFeedOrigin.EXISTING_FEED -> QuestionFeedPlacement(
        shouldAppend = false,
        attribution = QuestionFeedAttribution(speaker = null, isUser = false),
    )
}
