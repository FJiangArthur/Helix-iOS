// The one seam between the app shell and every transcription backend.
// Device (android.speech), OpenAI Realtime (websocket) and Omi (relay feed)
// all present the same surface so the bridge can swap them without knowing
// how audio reaches the recognizer.
package com.artjiang.helix.speech

import com.artjiang.helix.core.TranscriptSegment
import kotlinx.coroutines.flow.StateFlow

/**
 * A start/stop transcript producer.
 *
 * Contract shared by every backend:
 * - [isListening] is true only while the source is actually producing; any
 *   terminal failure resets it so the UI can never stick on "Listening".
 * - [errorMessage] is a clearable, user-facing string ("" when none).
 * - [onSegment] may be invoked on any thread; the bridge hops to its own
 *   scope before touching UI state.
 */
interface TranscriptSource {
    val isListening: StateFlow<Boolean>
    val partialTranscript: StateFlow<String>
    val errorMessage: StateFlow<String>

    /** Partials and finals; finals drive the conversation pipeline. */
    var onSegment: ((TranscriptSegment) -> Unit)?

    fun start()
    fun stop()
    fun clearError()
}

/**
 * Which backend produces the transcript. Shell-owned (persisted by
 * SettingsRepository under its own key), never part of the shared
 * `HelixSettings` domain type.
 */
enum class TranscriptionSource { DEVICE, OPENAI_REALTIME, OMI }

/**
 * How questions reach the AI, independent of the transcript source:
 * [AUTO_DETECT] runs every final through question detection;
 * [ON_DEMAND] stays quiet until the user asks (Ask now / right touchpad),
 * then answers from the last minute of conversation.
 */
enum class QuestionMode { AUTO_DETECT, ON_DEMAND }
