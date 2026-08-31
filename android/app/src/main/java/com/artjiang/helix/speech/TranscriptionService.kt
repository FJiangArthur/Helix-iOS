// Continuous speech-to-text over android.speech.SpeechRecognizer.
// Android counterpart of the iOS Apple (SFSpeechRecognizer) backend in
// ios/Runner/SpeechStreamRecognizer.swift.
//
// This is the DEVICE backend behind the [TranscriptSource] seam; the OpenAI
// Realtime backend lives in OpenAIRealtimeTranscriber.kt and the Omi relay
// backend in OmiTranscriptSource.kt.
package com.artjiang.helix.speech

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionService
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
class TranscriptionService(context: Context) : TranscriptSource {

    private val appContext = context.applicationContext

    private var recognizer: SpeechRecognizer? = null

    /** True while the user wants to listen — survives internal restarts. */
    private val listeningState = MutableStateFlow(false)
    override val isListening: StateFlow<Boolean> = listeningState.asStateFlow()

    private val partialState = MutableStateFlow("")
    override val partialTranscript: StateFlow<String> = partialState.asStateFlow()

    private val errorState = MutableStateFlow("")
    override val errorMessage: StateFlow<String> = errorState.asStateFlow()

    /** Invoked for every segment; finals drive the conversation pipeline. */
    override var onSegment: ((TranscriptSegment) -> Unit)? = null

    /** True while a restart is in flight, to avoid double-starting. */
    private var restarting = false

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Consecutive BUSY/CLIENT failures. Reset when a session actually starts
     * delivering (onReadyForSpeech) — without this bound, a recognizer held by
     * another app produced an unbounded main-thread create/destroy loop with
     * the UI pinned on "Listening" and no error ever surfaced.
     */
    private var busyRestartCount = 0

    fun isAvailable(): Boolean = SpeechRecognizer.isRecognitionAvailable(appContext)

    override fun clearError() {
        errorState.value = ""
    }

    /**
     * Must be called on the main thread — [SpeechRecognizer] requires it.
     */
    override fun start() {
        if (listeningState.value) return
        if (!isAvailable()) {
            fail("Speech recognition is not available on this device.")
            return
        }
        errorState.value = ""
        partialState.value = ""
        busyRestartCount = 0
        listeningState.value = true
        beginSession()
    }

    /** Main thread. Stops listening and clears the partial transcript. */
    override fun stop() {
        listeningState.value = false
        restarting = false
        busyRestartCount = 0
        mainHandler.removeCallbacksAndMessages(null)
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
        val instance = createRecognizer()
        recognizer = instance
        instance.setRecognitionListener(listener)
        runCatching { instance.startListening(recognizerIntent()) }
            .onFailure { fail(it.message ?: "Could not start the recognizer.") }
    }

    /** Human-readable name of the recognition service in use, for error text. */
    @Volatile
    private var activeServiceLabel: String = "default"

    /**
     * Prefer Google's recognition service over the device default. On Samsung
     * devices the default is Bixby's service, which fails continuous dictation
     * with SERVER/CLIENT errors; Google's handles the restart-per-segment
     * pattern reliably. Fall back to the platform on-device recognizer
     * (API 31+) and finally the default.
     */
    private fun createRecognizer(): SpeechRecognizer {
        val google = resolveRecognitionService(GOOGLE_RECOGNIZER_PACKAGE)
        if (google != null) {
            activeServiceLabel = "Google"
            return SpeechRecognizer.createSpeechRecognizer(appContext, google)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(appContext)
        ) {
            activeServiceLabel = "on-device"
            return SpeechRecognizer.createOnDeviceSpeechRecognizer(appContext)
        }
        activeServiceLabel = "default"
        return SpeechRecognizer.createSpeechRecognizer(appContext)
    }

    private fun resolveRecognitionService(packageName: String): ComponentName? =
        runCatching {
            appContext.packageManager
                .queryIntentServices(Intent(RecognitionService.SERVICE_INTERFACE), 0)
                .firstOrNull { it.serviceInfo?.packageName == packageName }
                ?.serviceInfo
                ?.let { ComponentName(it.packageName, it.name) }
        }.getOrNull()

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
        override fun onReadyForSpeech(params: Bundle?) {
            // The session came up — the recognizer is no longer busy/wedged.
            busyRestartCount = 0
        }
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
                // is momentarily wedged. Bounded retries with backoff, then it
                // surfaces as a hard error.
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                SpeechRecognizer.ERROR_CLIENT,
                -> {
                    partialState.value = ""
                    busyRestartCount += 1
                    if (busyRestartCount > MAX_BUSY_RESTARTS) {
                        fail(describe(error))
                    } else {
                        mainHandler.postDelayed(
                            { restartIfListening() },
                            BUSY_RESTART_DELAY_MILLIS * busyRestartCount,
                        )
                    }
                }

                else -> fail(describe(error))
            }
        }
    }

    private fun firstResult(bundle: Bundle?): String? =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()

    private fun describe(error: Int): String {
        val base = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Microphone error. Check that no other app is recording."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is required to listen."
            SpeechRecognizer.ERROR_NETWORK -> "Speech recognition network error."
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition timed out."
            SpeechRecognizer.ERROR_SERVER -> "The speech recognition service returned an error."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                "The speech recognizer is busy — another app may be using the microphone."
            SpeechRecognizer.ERROR_CLIENT -> "The speech recognizer keeps failing to start."
            // API 31+ codes, spelled out so a Samsung/Bixby failure is diagnosable.
            12 -> "Speech recognition does not support the current language."
            13 -> "The language pack for speech recognition is not available."
            14 -> "The speech recognition server is disconnected."
            15 -> "Too many speech recognition requests."
            else -> "Speech recognition stopped (code $error)."
        }
        return "$base [$activeServiceLabel recognizer]"
    }

    private companion object {
        const val GOOGLE_RECOGNIZER_PACKAGE = "com.google.android.googlequicksearchbox"
        const val MAX_BUSY_RESTARTS = 3
        const val BUSY_RESTART_DELAY_MILLIS = 400L
    }
}
