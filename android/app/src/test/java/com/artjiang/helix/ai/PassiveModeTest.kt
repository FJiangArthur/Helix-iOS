package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PassiveModeTest {

    private class RecordingProvider : AnswerProvider {
        override val kind: ProviderKind = ProviderKind.DETERMINISTIC
        override val model: String = "recording"
        val requests = mutableListOf<AnswerRequest>()

        override suspend fun answer(
            request: AnswerRequest,
            onDelta: ((String) -> Unit)?,
        ): AnswerResponse {
            requests += request
            val text = "answer for ${request.question}"
            onDelta?.invoke(text)
            return AnswerResponse(text, kind, model)
        }
    }

    private fun passiveEngine(provider: AnswerProvider) = ConversationEngine(
        settings = HelixSettings(mode = ConversationMode.PASSIVE),
        provider = provider,
    )

    // MARK: - Classifier heuristics (port of PassiveTriggerClassifier.swift)

    @Test
    fun `direct question triggers answer`() {
        val result = PassiveTriggerClassifier().decision("What is the capital of France?")
        assertEquals(PassiveTriggerAction.ANSWER, result.action)
        assertEquals(PassiveTriggerKind.DIRECT_QUESTION, result.kind)
    }

    @Test
    fun `monologue is ignored`() {
        val result = PassiveTriggerClassifier()
            .decision("So then we moved the deploy to Thursday and told the team about it")
        assertEquals(PassiveTriggerAction.IGNORE, result.action)
        assertEquals(PassiveTriggerKind.MONOLOGUE, result.kind)
    }

    @Test
    fun `filler is ignored`() {
        val result = PassiveTriggerClassifier().decision("okay")
        assertEquals(PassiveTriggerAction.IGNORE, result.action)
        assertEquals(PassiveTriggerKind.FILLER, result.kind)
    }

    @Test
    fun `rhetorical phrasing is ignored`() {
        val result = PassiveTriggerClassifier()
            .decision("It was a pretty rough launch, you know what i mean")
        assertEquals(PassiveTriggerAction.IGNORE, result.action)
        assertEquals(PassiveTriggerKind.RHETORICAL, result.kind)
    }

    @Test
    fun `implicit help request triggers answer`() {
        val result = PassiveTriggerClassifier()
            .decision("I'm stuck on the migration script for the sessions table")
        assertEquals(PassiveTriggerAction.ANSWER, result.action)
        assertEquals(PassiveTriggerKind.IMPLICIT_ASK, result.kind)
    }

    // MARK: - Engine gating

    @Test
    fun `passive mode stays silent on conversational monologue`() = runTest {
        val provider = RecordingProvider()
        val engine = passiveEngine(provider)

        val turn = engine.processLiveTranscript(
            "So then we moved the deploy to Thursday and told the team about it",
        )

        assertNull("no answer in passive mode for a monologue", turn.answer)
        assertEquals(SuppressionReason.PASSIVE_FILTERED, turn.suppressed)
        assertEquals("provider never called", 0, provider.requests.size)
    }

    @Test
    fun `passive mode answers a direct question`() = runTest {
        val provider = RecordingProvider()
        val engine = passiveEngine(provider)

        val turn = engine.processLiveTranscript("What is the capital of France?")

        assertNotNull(turn.answer)
        assertEquals(1, provider.requests.size)
        assertEquals(ConversationMode.PASSIVE, provider.requests.single().mode)
    }

    @Test
    fun `passive mode emits a correction instead of an answer for a false claim`() = runTest {
        val provider = RecordingProvider()
        val engine = passiveEngine(provider)

        val turn = engine.processLiveTranscript(
            "As I always say, RAG means random answer generation",
        )

        assertEquals("RAG means retrieval augmented generation.", turn.passiveReminder)
        assertNull(turn.answer)
        assertEquals("provider never called for a correction", 0, provider.requests.size)
    }

    @Test
    fun `active mode is unaffected by the passive gate`() = runTest {
        val provider = RecordingProvider()
        val engine = ConversationEngine(
            settings = HelixSettings(mode = ConversationMode.ACTIVE),
            provider = provider,
        )

        val turn = engine.processLiveTranscript("What is the capital of France?")

        assertNotNull(turn.answer)
        assertNull(turn.suppressed)
    }

    // MARK: - CJK-stripping normalize() bug (was `[^a-z0-9 '?]`, which deleted
    // every Chinese character; `\\p{L}` now keeps any-script letters).

    @Test
    fun `chinese text survives normalization instead of collapsing to empty`() {
        // Before the fix: normalize("你今天有空吗") == "" (every CJK character
        // was stripped by [^a-z0-9 '?]), which is indistinguishable from an
        // empty segment — the classifier's very first branch.
        val normalized = PassiveTriggerClassifier.normalize("你今天有空吗")
        assertTrue("Chinese characters must survive normalization", normalized.isNotEmpty())
        assertEquals("你今天有空吗", normalized)
    }

    @Test
    fun `mixed chinese and latin text keeps both scripts after normalization`() {
        val normalized = PassiveTriggerClassifier.normalize("Helix 你好 v2!")
        assertEquals("helix 你好 v2", normalized)
    }

    @Test
    fun `a chinese question mark still triggers ANSWER directly`() {
        // This path worked even before the fix (isQuestionSuffix checks the
        // un-normalized string), so it is a control case: unaffected by the
        // regex change, must keep passing.
        val result = PassiveTriggerClassifier().decision("你今天有空吗？")
        assertEquals(PassiveTriggerAction.ANSWER, result.action)
        assertEquals(PassiveTriggerKind.DIRECT_QUESTION, result.kind)
    }

    @Test
    fun `chinese monologue without a question mark is no longer treated as an empty segment`() {
        // Before the fix, ANY Chinese text with no literal "？" normalized to
        // "" and was misclassified as FILLER "Empty passive segment" — not
        // MONOLOGUE, not AMBIGUOUS, not even a length check: total silence
        // with the wrong reason. After the fix it reaches a real branch
        // (MONOLOGUE here, since it is a statement with no ask marker) with a
        // reason that actually reflects the content.
        val result = PassiveTriggerClassifier()
            .decision("我们决定把发布往后推迟一周然后通知了整个团队")
        assertFalse(
            "a real Chinese utterance must not be classified as an empty segment",
            result.kind == PassiveTriggerKind.FILLER && result.reason == "Empty passive segment.",
        )
    }
}
