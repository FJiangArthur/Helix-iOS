// "Ask ChatGPT" through helix-relay (plan A / contract 0.3 §6). One question
// at a time: a new one cancels the running stream. The phone watches [state]
// for the streamed text; the lens gets one ANSWER card on completion (or a
// NOTICE on failure) via [show], which the bridge routes to a live cue or an
// idle AnswerCard. With no relay configured the app's own answer provider
// ([fallback]) answers instead; a configured relay that fails never falls back.
package com.artjiang.helix.conversate

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

data class AskState(
    val question: String = "",
    val answer: String = "",
    val streaming: Boolean = false,
    val error: String? = null,
    /** Identifies the stream this state belongs to. */
    val token: Long = 0,
    /** True when no relay is set up and the app's own answer provider answered. */
    val viaFallback: Boolean = false,
)

/** Streams an answer: [onDelta] per chunk, returns the whole text. */
typealias AskStream = suspend (question: String, context: String?, deep: Boolean, onDelta: (String) -> Unit) -> String

class AskCoordinator(
    private val scope: CoroutineScope,
    private val ask: AskStream,
    private val show: (CueType, String) -> Unit,
    /** Contract 0.3 §6: used only when the relay is not configured. */
    private val fallback: AskStream? = null,
) {
    companion object {
        const val FALLBACK_FAILURE = "Ask failed: AI provider error"

        fun failureText(e: RelayException): String = "Ask failed: " + when (e.kind) {
            RelayException.Kind.UNREACHABLE -> "relay unreachable"
            RelayException.Kind.NOT_CONFIGURED -> "relay not set up"
            RelayException.Kind.UNAUTHORIZED -> "relay key rejected"
            RelayException.Kind.FAILED -> "relay error"
        }
    }

    private val stateFlow = MutableStateFlow(AskState())
    val state: StateFlow<AskState> = stateFlow.asStateFlow()
    private var job: Job? = null
    private val nextToken = AtomicLong(0)

    fun ask(question: String, context: String?, deep: Boolean) {
        val q = question.trim()
        if (q.isEmpty()) return
        job?.cancel()
        // Each stream owns a token: a superseded stream (even for the same
        // question text) may still deliver deltas from its OkHttp thread.
        val token = nextToken.incrementAndGet()
        stateFlow.value = AskState(question = q, streaming = true, token = token)
        val onDelta: (String) -> Unit = { delta ->
            stateFlow.update { if (it.token == token) it.copy(answer = it.answer + delta) else it }
        }
        job = scope.launch {
            var viaFallback = false
            try {
                val answer = try {
                    ask(q, context, deep, onDelta)
                } catch (e: RelayException) {
                    val fb = fallback
                    if (e.kind != RelayException.Kind.NOT_CONFIGURED || fb == null) throw e
                    viaFallback = true
                    stateFlow.update { if (it.token == token) it.copy(viaFallback = true) else it }
                    fb(q, context, deep, onDelta)
                }.trim()
                if (stateFlow.value.token != token) return@launch
                stateFlow.value = AskState(question = q, answer = answer, token = token, viaFallback = viaFallback)
                if (answer.isNotEmpty()) show(CueType.ANSWER, answer)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (stateFlow.value.token != token) return@launch
                val text = when {
                    viaFallback -> FALLBACK_FAILURE
                    e is RelayException -> failureText(e)
                    else -> "Ask failed: relay error"
                }
                stateFlow.update { it.copy(streaming = false, error = text) }
                show(CueType.NOTICE, text)
            }
        }
    }

    fun cancel() {
        job?.cancel()
        stateFlow.update { it.copy(streaming = false) }
    }
}
