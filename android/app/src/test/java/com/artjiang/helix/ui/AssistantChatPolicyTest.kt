package com.artjiang.helix.ui

import com.artjiang.helix.FeedEntry
import com.artjiang.helix.ai.AnswerTier
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantChatPolicyTest {
    private fun answer(tier: AnswerTier) = FeedEntry(
        id = tier.ordinal.toLong(),
        kind = FeedEntry.Kind.ANSWER,
        text = "Answer",
        model = if (tier == AnswerTier.FAST) "fast-model" else "smart-model",
        question = "What is RAG?",
        answerTier = tier,
        atMillis = 1L,
        isUser = false,
    )

    @Test
    fun `automatic answer offers one deep action but its smart child does not recurse`() {
        assertTrue(shouldOfferThinkDeeper(answer(AnswerTier.FAST)))
        assertFalse(shouldOfferThinkDeeper(answer(AnswerTier.SMART)))
    }

    @Test
    fun `legacy answer without truthful tier does not claim it can deepen`() {
        assertFalse(shouldOfferThinkDeeper(answer(AnswerTier.FAST).copy(answerTier = null)))
    }
}
