// Continuous speech-to-text over android.speech.SpeechRecognizer.
// Android counterpart of the iOS Apple (SFSpeechRecognizer) backend in
// ios/Runner/SpeechStreamRecognizer.swift.
//
// SCOPE (v1): on-device / Google recognizer only. The iOS shell also has an
// OpenAI Realtime backend (OpenAIRealtimeTranscriber.swift) and a Whisper batch
// backend; both are deliberately out of scope for the Android v1 port —
// memory/feedback_openai_transcription.md records that the OpenAI realtime path
// is the unreliable one anyway, and Apple Cloud (i.e. the platform recognizer)
// is the preferred backend. Wiring OpenAI here would mean adding a raw-audio
// capture + websocket path with no reuse from this class.
package com.artjiang.helix.speech

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.artjiang.helix.core.TranscriptSegment
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

/**
 * Restarting wrapper around [SpeechRecognizer] that behaves like a continuous
 * dictation stream: each recognition session ends after a pause, and the
 * service immediately starts another while [isListening] is true.
 *
 * Fix of an iOS defect: any terminal failure resets the listening state and
 * publishes a *clearable* error. On iOS a recognizer failure could leave the UI
 * pinned to "Listening" with no way to recover short of relaunching, because
 * the error was surfaced without unsetting the flag.
 */
class TranscriptionService(context: Context) {

    private val appContext = context.applicationContext

    private var recognizer: SpeechRecognizer? = null

    /** True while the user wants to listen — survives internal restarts. */
    private val listeningState = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = listeningState.asStateFlow()

    private val partialState = MutableStateFlow("")
    val partialTranscript: StateFlow<String> = partialState.asStateFlow()

    private val errorState = MutableStateFlow("")
    val errorMessage: StateFlow<String> = errorState.asStateFlow()

    /** Invoked for every segment; finals drive the conversation pipeline. */
    var onSegment: ((TranscriptSegment) -> Unit)? = null

    /** True while a restart is in flight, to avoid double-starting. */
    private var restarting = false

    fun isAvailable(): Boolean = SpeechRecognizer.isRecognitionAvailable(appContext)

    fun clearError() {
        errorState.value = ""
    }

    /**
     * Must be called on the main thread — [SpeechRecognizer] requires it.
     */
    fun start() {
        if (listeningState.value) return
        if (!isAvailable()) {
            fail("Speech recognition is not available on this device.")
            return
        }
        errorState.value = ""
        partialState.value = ""
        listeningState.value = true
        beginSession()
    }

    /** Main thread. Stops listening and clears the partial transcript. */
    fun stop() {
        listeningState.value = false
        restarting = false
        partialState.value = ""
        runCatching { recognizer?.stopListening() }
        destroyRecognizer()
    }

    fun toggle() {
        if (listeningState.value) stop() else start()
    }

    // MARK: - Internals

    private fun beginSession() {
        destroyRecognizer()
        val instance = SpeechRecognizer.createSpeechRecognizer(appContext)
        recognizer = instance
        instance.setRecognitionListener(listener)
        runCatching { instance.startListening(recognizerIntent()) }
            .onFailure { fail(it.message ?: "Could not start the recognizer.") }
    }

    private fun destroyRecognizer() {
        runCatching {
            recognizer?.cancel()
            recognizer?.destroy()
        }
        recognizer = null
    }

    private fun recognizerIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, appContext.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Keeps the session alive across natural pauses where supported.
                putExtra(RecognizerIntent.EXTRA_MASK_OFFENSIVE_WORDS, false)
            }
        }

    /** Restarts the recognizer if the user is still listening. */
    private fun restartIfListening() {
        if (!listeningState.value || restarting) return
        restarting = true
        // Recreate immediately; the platform recognizer does not support being
        // reused after onResults/onError, so a fresh instance per segment is
        // the supported way to get continuous dictation.
        beginSession()
        restarting = false
    }

    private fun fail(message: String) {
        // Reset the listening state so the UI can never stick on "Listening".
        listeningState.value = false
        restarting = false
        partialState.value = ""
        destroyRecognizer()
        errorState.value = message
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) = Unit
        override fun onBeginningOfSpeech() = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onEndOfSpeech() {
            // onResults or onError follows; the restart happens there.
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = firstResult(partialResults) ?: return
            if (text.isBlank()) return
            partialState.value = text
            onSegment?.invoke(
                TranscriptSegment(text = text, isFinal = false, timestampMillis = System.currentTimeMillis()),
            )
        }

        override fun onResults(results: Bundle?) {
            val text = firstResult(results)?.trim().orEmpty()
            partialState.value = ""
            if (text.isNotEmpty()) {
                onSegment?.invoke(
                    TranscriptSegment(text = text, isFinal = true, timestampMillis = System.currentTimeMillis()),
                )
            }
            restartIfListening()
        }

        override fun onError(error: Int) {
            when (error) {
                // Benign: a silent stretch or a session that produced nothing.
                // Keep listening and start the next session, exactly as the
                // iOS backend swallows its equivalent no-speech conditions.
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                -> {
                    partialState.value = ""
                    restartIfListening()
                }

                // Transient: another app grabbed the recognizer, or the service
                // is momentarily wedged. One restart attempt, then it will
                // surface as a hard error if it recurs.
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                SpeechRecognizer.ERROR_CLIENT,
                -> {
                    partialState.value = ""
                    restartIfListening()
                }

                else -> fail(describe(error))
            }
        }
    }

    private fun firstResult(bundle: Bundle?): String? =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()

    private fun describe(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "Microphone error. Check that no other app is recording."
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is required to listen."
        SpeechRecognizer.ERROR_NETWORK -> "Speech recognition network error."
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition timed out."
        SpeechRecognizer.ERROR_SERVER -> "The speech recognition service returned an error."
        else -> "Speech recognition stopped (code $error)."
    }
}
