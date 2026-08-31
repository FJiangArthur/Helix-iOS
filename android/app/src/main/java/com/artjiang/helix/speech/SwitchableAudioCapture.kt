// Swappable AudioCapture facade. The bridge constructs the realtime
// transcriber once, so the only way to feed it something other than the
// microphone (debug fixture injection, tests) is a delegate it can replace
// between sessions.
package com.artjiang.helix.speech

/**
 * [AudioCapture] that forwards everything to a replaceable [delegate].
 *
 * The delegate defaults to the real microphone ([AudioRecordCapture]) and can
 * be replaced via [swap] — but **only while capture is stopped**: the running
 * delegate owns a capture thread and the consumer's `onPcm` callbacks, and
 * replacing it mid-stream would orphan that thread while a second one starts.
 * [swap] therefore throws if called between [start] and [stop]. Callers
 * (HelixBridge's debug audio injection) always stop the transcriber — which
 * stops this capture — before swapping.
 *
 * Thread-safety: [start]/[stop] are called from the transcriber on the main
 * thread; [swap] from the bridge on the same thread. The fields are
 * `@Volatile` so [sampleRateHz] reads from the audio thread see the delegate
 * that was actually started.
 */
class SwitchableAudioCapture(
    initial: AudioCapture = AudioRecordCapture(),
) : AudioCapture {

    @Volatile
    private var delegate: AudioCapture = initial

    @Volatile
    private var running = false

    /** The delegate that currently backs this capture (for tests/diagnostics). */
    val current: AudioCapture
        get() = delegate

    /** Valid after [start], mirroring the started delegate's rate. */
    override val sampleRateHz: Int
        get() = delegate.sampleRateHz

    override fun start(onPcm: (ShortArray, Int) -> Unit, onError: (String) -> Unit) {
        if (running) return
        running = true
        delegate.start(onPcm, onError)
    }

    override fun stop() {
        // Always forward: the delegate guards its own idempotence, and a
        // defensive stop() from the consumer must reach it.
        running = false
        delegate.stop()
    }

    /**
     * Replaces the delegate. Only legal while stopped — see the class doc.
     *
     * @throws IllegalStateException if capture is running.
     */
    fun swap(newDelegate: AudioCapture) {
        check(!running) { "SwitchableAudioCapture.swap() called while capture is running" }
        delegate = newDelegate
    }
}
