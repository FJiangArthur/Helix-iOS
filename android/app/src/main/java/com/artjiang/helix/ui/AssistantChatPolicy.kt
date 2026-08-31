package com.artjiang.helix.ui

import com.artjiang.helix.FeedEntry
import com.artjiang.helix.ai.AnswerTier

/** A FAST automatic answer may be deliberately re-asked once on SMART. */
internal fun shouldOfferThinkDeeper(entry: FeedEntry): Boolean =
    entry.kind == FeedEntry.Kind.ANSWER &&
        entry.answerTier == AnswerTier.FAST &&
        !entry.question.isNullOrBlank()
