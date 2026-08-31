// Selects one TranscriptSource at a time and presents the union of their
// state to the bridge, so "is anything listening", "what is being said" and
// "what went wrong" have a single owner regardless of backend.
package com.artjiang.helix.speech

import com.artjiang.helix.core.TranscriptSegment
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

/**
 * Fan-in / mutual exclusion over the configured sources.
 *
 * - [start] stops every other source before starting the requested one, so
 *   phone mic and Omi can never run together.
 * - [errorMessage] is the error of the source that was started last (the
 *   one the user is looking at); starting a different source clears it. A
 *   source that failed keeps its error visible until then.
 * - [active] is the started source while it is actually listening, and
 *   flips to null the moment that source stops on its own (failure, external
 *   stop) — the UI keys "Listening · OpenAI" off it.
 *
 * [scope] only hosts the derived StateFlows; use the bridge's serial scope.
 */
class TranscriptSourceSwitch(
    private val sources: Map<TranscriptionSource, TranscriptSource>,
    scope: CoroutineScope,
) {
    private val order: List<TranscriptionSource> = sources.keys.toList()

    private val selectedState = MutableStateFlow<TranscriptionSource?>(null)
    private val lastStartedState = MutableStateFlow<TranscriptionSource?>(null)

    /** The last source passed to [start], whether or not it is listening. */
    val selected: StateFlow<TranscriptionSource?> = selectedState.asStateFlow()

    /** Invoked for every segment from whichever source produced it. */
    var onSegment: ((TranscriptSegment) -> Unit)? = null

    init {
        sources.values.forEach { source ->
            source.onSegment = { segment -> onSegment?.invoke(segment) }
        }
    }

    val active: StateFlow<TranscriptionSource?> =
        combine(selectedState, combine(order.map { sources.getValue(it).isListening }) { it }) { selected, listening ->
            selected?.takeIf { kind -> listening[order.indexOf(kind)] }
        }.stateIn(scope, SharingStarted.Eagerly, null)

    val isListening: StateFlow<Boolean> =
        combine(order.map { sources.getValue(it).isListening }) { flags -> flags.any { it } }
            .stateIn(scope, SharingStarted.Eagerly, false)

    val partialTranscript: StateFlow<String> =
        combine(active, combine(order.map { sources.getValue(it).partialTranscript }) { it }) { active, partials ->
            active?.let { partials[order.indexOf(it)] }.orEmpty()
        }.stateIn(scope, SharingStarted.Eagerly, "")

    val errorMessage: StateFlow<String> =
        combine(lastStartedState, combine(order.map { sources.getValue(it).errorMessage }) { it }) { last, errors ->
            last?.let { errors[order.indexOf(it)] }.orEmpty()
        }.stateIn(scope, SharingStarted.Eagerly, "")

    fun source(kind: TranscriptionSource): TranscriptSource? = sources[kind]

    fun start(kind: TranscriptionSource) {
        val target = sources[kind] ?: return
        sources.forEach { (other, source) -> if (other != kind) source.stop() }
        val previous = lastStartedState.value
        if (previous != null && previous != kind) sources[previous]?.clearError()
        lastStartedState.value = kind
        selectedState.value = kind
        target.start()
    }

    /** Stops every source. Safe to call when nothing is listening. */
    fun stop() {
        sources.values.forEach { it.stop() }
        selectedState.value = null
    }

    fun toggle(kind: TranscriptionSource) {
        if (isListening.value) stop() else start(kind)
    }

    fun clearError() {
        sources.values.forEach { it.clearError() }
    }
}
