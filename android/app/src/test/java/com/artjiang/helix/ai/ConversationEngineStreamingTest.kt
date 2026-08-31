package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The engine's optional token passthrough, and its staleness gate. */
class ConversationEngineStreamingTest {

    /** Emits [chunks] as deltas, then returns their concatenation. */
    private class ChunkedProvider(
        private val chunks: List<String>,
        override val kind: ProviderKind = ProviderKind.DETERMINISTIC,
        override val model: String = "chunked",
    ) : AnswerProvider {
        var sawDeltaSink: Boolean = false
            private set

        override suspend fun answer(
            request: AnswerRequest,
            onDelta: ((String) -> Unit)?,
        ): AnswerResponse {
            sawDeltaSink = onDelta != null
            chunks.forEach { onDelta?.invoke(it) }
            return AnswerResponse(chunks.joinToString(""), kind, model)
        }
    }

    /**
     * Blocks inside the provider until released, emitting a delta before and
     * after — the window in which a newer turn can supersede this one.
     */
    private class GatedProvider(
        private val started: CompletableDeferred<Unit>,
        private val release: CompletableDeferred<Unit>,
        override val kind: ProviderKind = ProviderKind.DETERMINISTIC,
        override val model: String = "gated",
    ) : AnswerProvider {
        override suspend fun answer(
            request: AnswerRequest,
            onDelta: ((String) -> Unit)?,
        ): AnswerResponse {
            onDelta?.invoke("early ")
            started.complete(Unit)
            release.await()
            onDelta?.invoke("late")
            return AnswerResponse("early late", kind, model)
        }
    }

    @Test
    fun `live transcript forwards deltas in order and still returns the whole turn`() = runTest {
        val engine = ConversationEngine(provider = ChunkedProvider(listOf("An ", "LLM ", "predicts.")))
        val deltas = mutableListOf<String>()

        val turn = engine.processLiveTranscript("What is an LLM?") { deltas += it }

        assertEquals(listOf("An ", "LLM ", "predicts."), deltas)
        assertNotNull(turn.answer)
        assertEquals("An LLM predicts.", turn.answer!!.text)
        assertEquals(deltas.joinToString(""), turn.answer!!.text)
        assertEquals(turn.answer, engine.activeAnswer)
    }

    @Test
    fun `typed question forwards deltas`() = runTest {
        val engine = ConversationEngine(provider = ChunkedProvider(listOf("a", "b")))
        val deltas = mutableListOf<String>()

        val turn = engine.answerTextQuestion("Explain RAG") { deltas += it }

        assertEquals(listOf("a", "b"), deltas)
        assertEquals("ab", turn.answer!!.text)
    }

    @Test
    fun `recent context answer forwards deltas`() = runTest {
        val engine = ConversationEngine(provider = ChunkedProvider(listOf("x", "y")))
        val deltas = mutableListOf<String>()

        val turn = engine.answerFromRecentContext("Heard: something\nWhat did they mean?") { deltas += it }

        assertEquals(listOf("x", "y"), deltas)
        assertEquals("xy", turn.answer!!.text)
    }

    @Test
    fun `omitting the sink leaves the provider on its buffered path`() = runTest {
        val provider = ChunkedProvider(listOf("one"))
        val engine = ConversationEngine(provider = provider)

        val turn = engine.processLiveTranscript("What is an LLM?")

        assertEquals(false, provider.sawDeltaSink)
        assertEquals("one", turn.answer!!.text)
    }

    @Test
    fun `deltas from a superseded turn are dropped`() = runTest {
        val started = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val engine = ConversationEngine(provider = GatedProvider(started, release))
        val deltas = mutableListOf<String>()

        val first = async { engine.processLiveTranscript("What is an LLM?") { deltas += it } }
        started.await()
        assertEquals(listOf("early "), deltas)

        // A newer turn bumps the generation while the first answer is in flight.
        engine.processLiveTranscript("Unrelated statement.")
        release.complete(Unit)
        val staleTurn = first.await()

        // "late" arrived after the newer turn started: the gate dropped it, so
        // it can never paint over the newer turn's live text.
        assertEquals(listOf("early "), deltas)
        // The Turn itself is unchanged — the caller still sees the full answer;
        // only the engine's committed state rejected it as stale.
        assertEquals("early late", staleTurn.answer!!.text)
        assertEquals(null, engine.activeAnswer)
    }

    @Test
    fun `suppressed turns never invoke the sink`() = runTest {
        val engine = ConversationEngine(
            settings = HelixSettings(autoAnswer = false),
            provider = ChunkedProvider(listOf("never")),
        )
        val deltas = mutableListOf<String>()

        val turn = engine.processLiveTranscript("What is an LLM?") { deltas += it }

        assertTrue(deltas.isEmpty())
        assertEquals(SuppressionReason.AUTO_ANSWER_DISABLED, turn.suppressed)
    }
}
