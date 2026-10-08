// "Ask ChatGPT" through helix-relay (plan A / contract 0.3 §6). One question
// at a time: a new one cancels the running stream. The phone watches [state]
// for the streamed text; the lens gets one ANSWER card on completion (or a
// NOTICE on failure) via [show], which the bridge routes to a live cue or an
// idle AnswerCard.
package com.artjiang.helix.conversate

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AskState(
    val question: String = "",
    val answer: String = "",
    val streaming: Boolean = false,
    val error: String? = null,
)

class AskCoordinator(
    private val scope: CoroutineScope,
    private val ask: suspend (question: String, context: String?, deep: Boolean, onDelta: (String) -> Unit) -> String,
    private val show: (CueType, String) -> Unit,
) {
    companion object {
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

    fun ask(question: String, context: String?, deep: Boolean) {
        val q = question.trim()
        if (q.isEmpty()) return
        job?.cancel()
        stateFlow.value = AskState(question = q, streaming = true)
        job = scope.launch {
            try {
                val answer = ask(q, context, deep) { delta ->
                    stateFlow.update { if (it.question == q) it.copy(answer = it.answer + delta) else it }
                }.trim()
                stateFlow.value = AskState(question = q, answer = answer)
                if (answer.isNotEmpty()) show(CueType.ANSWER, answer)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                val text = (e as? RelayException)?.let(::failureText) ?: "Ask failed: relay error"
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
