// HelixMode -> transcription backend (plan M). The mode is the user-facing
// switch; TranscriptionSource stays the shell's lower-level choice.
package com.artjiang.helix.conversate

import com.artjiang.helix.speech.TranscriptionSource

object HelixModePolicy {
    /**
     * The source a mode listens with, or null for DISPLAY_ONLY (no mic).
     * PHONE_MIC keeps whichever phone backend the user already picked in
     * Settings (Device or OpenAI Realtime) and only leaves Omi.
     */
    fun sourceFor(mode: HelixMode, current: TranscriptionSource): TranscriptionSource? = when (mode) {
        HelixMode.PHONE_MIC -> if (current == TranscriptionSource.OMI) TranscriptionSource.OPENAI_REALTIME else current
        HelixMode.OMI -> TranscriptionSource.OMI
        HelixMode.DISPLAY_ONLY -> null
    }

    fun canListen(mode: HelixMode): Boolean = mode != HelixMode.DISPLAY_ONLY

    /**
     * The source a glasses Ask listens with (contract 0.3 §6). Ask is an
     * explicit wearer action, so Display-only opens the phone mic for that one
     * utterance instead of refusing; other modes use their own source.
     */
    fun askSourceFor(mode: HelixMode, current: TranscriptionSource): TranscriptionSource =
        sourceFor(mode, current) ?: sourceFor(HelixMode.PHONE_MIC, current) ?: current

    /** Mode implied by a stored source, for installs that predate HelixMode. */
    fun modeFor(source: TranscriptionSource): HelixMode =
        if (source == TranscriptionSource.OMI) HelixMode.OMI else HelixMode.PHONE_MIC
}
