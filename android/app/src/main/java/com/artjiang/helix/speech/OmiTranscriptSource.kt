// Omi relay feed as a TranscriptSource. Owns the fragment→utterance
// coalescing that used to live in HelixBridge, so the bridge treats Omi
// exactly like the phone mic: a stream of partial and final segments.
package com.artjiang.helix.speech

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.data.OmiLiveSegment
import com.artjiang.helix.data.OmiLiveService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Wraps [OmiLiveService]. Omi's webhook delivers fragments, not whole
 * utterances, so fragments are joined until sentence-final punctuation or a
 * [gapMillis] quiet gap, then emitted as one final segment; the running
 * utterance is exposed as the partial. [onRawSegment] sees every fragment
 * untouched (speaker label included) for the HUD mirror.
 *
 * [scope] must be the caller's serial scope (the bridge's `Main.immediate`):
 * the gap timer and the service callback both mutate [utterance] on it.
 */
class OmiTranscriptSource(
    private val service: OmiLiveService,
    private val scope: CoroutineScope,
    private val feedUrl: () -> String?,
    private val gapMillis: Long = DEFAULT_GAP_MILLIS,
    private val clock: () -> Long = System::currentTimeMillis,
) : TranscriptSource {

    override val isListening: StateFlow<Boolean> = service.isActive

    private val partialState = MutableStateFlow("")
    override val partialTranscript: StateFlow<String> = partialState.asStateFlow()

    override val errorMessage: StateFlow<String> = service.errorMessage

    override var onSegment: ((TranscriptSegment) -> Unit)? = null

    /** Every relay fragment, before coalescing — for the speaker-labelled HUD mirror. */
    var onRawSegment: ((OmiLiveSegment) -> Unit)? = null

    private val utterance = StringBuilder()
    private var flushJob: Job? = null

    // Omi is the ONE source with real diarization; without carrying these
    // across coalescing the label is dropped and can never reach the feed,
    // which is why chat bubbles were impossible. Set from the fragment that
    // starts the utterance and reused by the delayed `flush()`, which no
    // longer has the triggering `OmiLiveSegment` in scope.
    private var utteranceSpeaker: String? = null
    private var utteranceIsUser: Boolean = true

    init {
        service.onSegment = ::handleSegment
    }

    /** Missing relay URL surfaces as the service's own "No relay URL configured." error. */
    override fun start() {
        if (service.isActive.value) return
        utterance.clear()
        utteranceSpeaker = null
        utteranceIsUser = true
        partialState.value = ""
        service.start(feedUrl().orEmpty())
    }

    /** Stops the feed and flushes any utterance still being assembled. */
    override fun stop() {
        service.stop()
        flush()
    }

    override fun clearError() = service.clearError()

    internal fun handleSegment(segment: OmiLiveSegment) {
        onRawSegment?.invoke(segment)
        val text = segment.text.trim()
        if (text.isEmpty()) return
        if (utterance.isEmpty()) {
            // First fragment of a new utterance sets the speaker for the
            // whole coalesced run, including the eventual `flush()`.
            utteranceSpeaker = segment.speaker
            utteranceIsUser = segment.isUser
        } else {
            utterance.append(' ')
        }
        utterance.append(text)
        val running = utterance.toString()
        partialState.value = running
        onSegment?.invoke(
            TranscriptSegment(
                text = running,
                isFinal = false,
                timestampMillis = clock(),
                speaker = segment.speaker,
                isUser = segment.isUser,
            ),
        )

        flushJob?.cancel()
        flushJob = null
        if (endsUtterance(text)) {
            flush()
        } else {
            flushJob = scope.launch {
                delay(gapMillis)
                flush()
            }
        }
    }

    private fun flush() {
        flushJob?.cancel()
        flushJob = null
        val text = utterance.toString().trim()
        utterance.clear()
        partialState.value = ""
        if (text.isNotEmpty()) {
            onSegment?.invoke(
                TranscriptSegment(
                    text = text,
                    isFinal = true,
                    timestampMillis = clock(),
                    // Omi is the ONE source with real diarization; without this
                    // the label is dropped at coalescing and can never reach
                    // the feed, which is why chat bubbles were impossible.
                    speaker = utteranceSpeaker,
                    isUser = utteranceIsUser,
                ),
            )
        }
        utteranceSpeaker = null
        utteranceIsUser = true
    }

    companion object {
        /** Quiet gap after a non-terminal fragment before it is treated as a whole utterance. */
        const val DEFAULT_GAP_MILLIS = 1_500L

        private const val TERMINAL_PUNCTUATION = ".?!。？！"

        fun endsUtterance(text: String): Boolean =
            text.trimEnd().lastOrNull()?.let { it in TERMINAL_PUNCTUATION } == true
    }
}
