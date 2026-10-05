// Hardware spike tooling for Conversate (spec §10, S2/S3). Debug aid only:
// it records raw touchpad/status frames and measures full-screen send latency
// so the input mapping and caption cadence are set from real G1 behaviour.
package com.artjiang.helix.g1

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class ProbeStats(val count: Int, val min: Long, val median: Long, val p90: Long, val max: Long) {
    fun summary(): String = "n=$count min=${min}ms median=${median}ms p90=${p90}ms max=${max}ms"

    companion object {
        fun of(durationsMillis: List<Long>): ProbeStats {
            if (durationsMillis.isEmpty()) return ProbeStats(0, 0, 0, 0, 0)
            val sorted = durationsMillis.sorted()
            val mid = sorted.size / 2
            val median = if (sorted.size % 2 == 0) (sorted[mid - 1] + sorted[mid]) / 2 else sorted[mid]
            val p90Index = (Math.ceil(sorted.size * 0.9).toInt() - 1).coerceIn(0, sorted.size - 1)
            return ProbeStats(sorted.size, sorted.first(), median, sorted[p90Index], sorted.last())
        }
    }
}

/** Ring buffer of raw inbound events, each stamped relative to the previous one. */
class TouchpadProbeLog(private val capacity: Int = 60, private val clock: () -> Long) {
    private val state = MutableStateFlow<List<String>>(emptyList())
    val entries: StateFlow<List<String>> = state.asStateFlow()
    private var last: Long? = null

    fun record(label: String) {
        val now = clock()
        val delta = last?.let { now - it } ?: 0L
        last = now
        state.value = (state.value + "+${delta}ms $label").takeLast(capacity)
    }
}
