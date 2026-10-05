// Turns the live transcript into Conversate cues (spec §5.4): debounce finals,
// one LLM call over the last minute + Prep Note, at most one new cue per
// [minGapMillis], never the same entity twice per session.
package com.artjiang.helix.conversate

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

class CueEngine(
    private val scope: CoroutineScope,
    private val classify: suspend (String, Int) -> String,
    private val prompt: CuePrompt,
    private val clock: () -> Long,
    private val emit: (Cue) -> Unit,
    private val debounceMillis: Long = 1_500,
    private val minGapMillis: Long = 8_000,
    private val windowMillis: Long = 60_000,
) {
    private data class Line(val text: String, val at: Long)

    private val window = ArrayDeque<Line>()
    private val shownKeys = linkedSetOf<String>()
    private val shownTitles = mutableListOf<String>()
    private var prepNote: String = ""
    private var lastEmitAt = Long.MIN_VALUE / 2
    private var debounce: Job? = null
    private var inFlight: Job? = null
    private val ids = AtomicLong(0)
    private val failureState = MutableStateFlow(0)
    val failures: StateFlow<Int> = failureState.asStateFlow()

    fun nextCueId(): Long = ids.incrementAndGet()

    fun setPrepNote(text: String?) { prepNote = text.orEmpty() }

    fun reset() {
        debounce?.cancel()
        inFlight?.cancel()
        window.clear(); shownKeys.clear(); shownTitles.clear()
        lastEmitAt = Long.MIN_VALUE / 2
        failureState.value = 0
    }

    fun onFinal(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        window.addLast(Line(trimmed, clock()))
        // Only the debounce restarts; an LLM call already in flight finishes.
        debounce?.cancel()
        debounce = scope.launch {
            delay(debounceMillis)
            if (inFlight?.isActive == true) return@launch
            inFlight = scope.launch { run() }
        }
    }

    private suspend fun run() {
        val now = clock()
        while (window.isNotEmpty() && now - window.first().at > windowMillis) window.removeFirst()
        if (window.isEmpty() || now - lastEmitAt < minGapMillis) return
        val text = prompt.render(
            transcript = window.joinToString(" ") { it.text },
            prepNote = prepNote,
            shown = shownTitles,
        )
        val raw = try {
            classify(text, prompt.maxTokens)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            failureState.value += 1
            return
        }
        failureState.value = 0
        val parsed = CueParser.parse(raw) ?: return
        val fresh = parsed.firstOrNull { key(it) !in shownKeys } ?: return
        shownKeys += key(fresh)
        shownTitles += fresh.title
        lastEmitAt = clock()
        emit(Cue(nextCueId(), fresh.type, fresh.title, fresh.body, fresh.detail, fresh.entity, createdAtMillis = lastEmitAt))
    }

    private fun key(c: ParsedCue) = (c.entity ?: c.title).lowercase().trim()
}
