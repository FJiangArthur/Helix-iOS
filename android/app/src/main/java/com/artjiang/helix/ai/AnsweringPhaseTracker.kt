// Pure state machine for the "Thinking…" UI signal. Extracted out of
// HelixBridge so the thinking/streaming transition is unit-testable without
// Android/BLE dependencies — HelixBridge only wires its StateFlow to this.
package com.artjiang.helix.ai

/**
 * Tracks whether the in-flight answer is "thinking" (started, no token yet)
 * or "streaming" (at least one token has arrived).
 *
 * A reasoning model (e.g. gpt-5.5) emits nothing while it deliberates, so a
 * technically-correct SSE stream still looks like a stalled spinner followed
 * by a sudden burst of text. [isThinking] gives the UI an honest third state
 * between "answering started" and "first token arrived" instead of leaving
 * the wearer staring at an undifferentiated spinner.
 *
 * Not thread-safe by itself — callers (here, [HelixBridge]) are expected to
 * only mutate it from their own single-threaded coroutine scope, exactly as
 * the surrounding streaming-sink/turn-id bookkeeping already does.
 */
class AnsweringPhaseTracker {
    private var thinking = false

    val isThinking: Boolean get() = thinking

    /** Call when a turn is armed to start answering (before any token arrives). */
    fun start() {
        thinking = true
    }

    /** Call on every delta. The first one ends the thinking phase. */
    fun onDelta() {
        thinking = false
    }

    /** Call when the turn ends (success, suppression, or error). */
    fun end() {
        thinking = false
    }
}
