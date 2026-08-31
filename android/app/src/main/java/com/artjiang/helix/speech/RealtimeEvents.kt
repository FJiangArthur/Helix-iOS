// Wire format for the OpenAI Realtime transcription websocket — pure
// encode/decode, no I/O. Uses the CURRENT nested `session.update` schema
// (session.type = "transcription", session.audio.input.{format,transcription,
// turn_detection}); the flat `transcription_session.update` shape the iOS
// shell started with is stale and errors on the live API.
package com.artjiang.helix.speech

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import java.util.Locale

/** Server → client events the transcriber cares about; everything else is [Unknown]. */
sealed class RealtimeServerEvent {
    /** `session.created|updated` or `transcription_session.created|updated`: audio may flow. */
    data object SessionReady : RealtimeServerEvent()

    data class TranscriptDelta(val itemId: String, val delta: String) : RealtimeServerEvent()

    data class TranscriptCompleted(val itemId: String, val transcript: String) : RealtimeServerEvent()

    data class TranscriptFailed(val message: String) : RealtimeServerEvent()

    /**
     * Top-level `error` event. [isAuth] marks a rejected key (no retry):
     * `invalid_api_key` code, or a message mentioning 401/auth.
     */
    data class ApiError(val message: String, val code: String?, val isAuth: Boolean) : RealtimeServerEvent()

    data class Unknown(val type: String) : RealtimeServerEvent()
}

object RealtimeEvents {
    /** Default realtime transcription model. */
    const val DEFAULT_MODEL = "gpt-live-transcribe"

    /** Curated list for pickers when the `/models` call is unavailable. */
    val FALLBACK_MODELS: List<String> =
        listOf(DEFAULT_MODEL, "gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1")

    /** The only input rate the session is configured for. */
    const val SAMPLE_RATE = 24_000

    const val DEFAULT_VAD_THRESHOLD = 0.35
    const val DEFAULT_PREFIX_PADDING_MS = 500
    const val DEFAULT_SILENCE_DURATION_MS = 1_000

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    /** Transcription languages the prompt is tuned for; anything else falls back to English. */
    private val supportedLanguages = setOf("en", "zh", "ja", "ko", "es", "ru", "fr", "de")

    /** Two-letter ISO code from [locale], mapped like the iOS transcriber. */
    fun languageCode(locale: Locale = Locale.getDefault()): String {
        val code = locale.language.lowercase(Locale.ROOT).substringBefore('-').substringBefore('_')
        return if (code in supportedLanguages) code else "en"
    }

    /**
     * Streaming models (gpt-live-transcribe) manage turns natively and the
     * server rejects a session.update carrying turn_detection for them
     * ("turn detection is not supported for this model"); batch-style
     * transcription models (gpt-4o-*-transcribe, whisper-1) need server VAD
     * to close turns.
     */
    fun supportsServerVad(model: String): Boolean =
        !model.trim().lowercase().contains("live")

    fun sessionUpdate(
        model: String = DEFAULT_MODEL,
        language: String = languageCode(),
        vadThreshold: Double = DEFAULT_VAD_THRESHOLD,
        prefixPaddingMs: Int = DEFAULT_PREFIX_PADDING_MS,
        silenceDurationMs: Int = DEFAULT_SILENCE_DURATION_MS,
    ): String = buildJsonObject {
        put("type", "session.update")
        putJsonObject("session") {
            put("type", "transcription")
            putJsonObject("audio") {
                putJsonObject("input") {
                    putJsonObject("format") {
                        put("type", "audio/pcm")
                        put("rate", SAMPLE_RATE)
                    }
                    putJsonObject("transcription") {
                        put("model", model.trim().ifEmpty { DEFAULT_MODEL })
                        put("language", language)
                    }
                    if (supportsServerVad(model)) {
                        putJsonObject("turn_detection") {
                            put("type", "server_vad")
                            put("threshold", vadThreshold)
                            put("prefix_padding_ms", prefixPaddingMs)
                            put("silence_duration_ms", silenceDurationMs)
                        }
                    }
                }
            }
        }
    }.toString()

    /**
     * Audio append frame. String template on purpose: this is sent ten times
     * a second with a multi-KB payload, and base64 never needs escaping.
     */
    fun audioAppend(base64: String): String = "{\"type\":\"input_audio_buffer.append\",\"audio\":\"$base64\"}"

    fun audioCommit(): String = "{\"type\":\"input_audio_buffer.commit\"}"

    fun audioClear(): String = "{\"type\":\"input_audio_buffer.clear\"}"

    fun parse(text: String): RealtimeServerEvent {
        val root = runCatching { json.parseToJsonElement(text) as? JsonObject }.getOrNull()
            ?: return RealtimeServerEvent.Unknown("")
        val type = root.string("type").orEmpty()
        return when (type) {
            "session.created", "session.updated",
            "transcription_session.created", "transcription_session.updated",
            -> RealtimeServerEvent.SessionReady

            "conversation.item.input_audio_transcription.delta" ->
                RealtimeServerEvent.TranscriptDelta(
                    itemId = root.string("item_id").orEmpty(),
                    delta = root.string("delta").orEmpty(),
                )

            "conversation.item.input_audio_transcription.completed" ->
                RealtimeServerEvent.TranscriptCompleted(
                    itemId = root.string("item_id").orEmpty(),
                    transcript = root.string("transcript").orEmpty(),
                )

            "conversation.item.input_audio_transcription.failed" -> {
                val error = root["error"] as? JsonObject
                RealtimeServerEvent.TranscriptFailed(error?.string("message") ?: "transcription failed")
            }

            "error" -> {
                val error = root["error"] as? JsonObject
                val message = error?.string("message") ?: root.string("message") ?: "unknown error"
                val code = error?.string("code")
                RealtimeServerEvent.ApiError(message, code, isAuthError(code, message))
            }

            else -> RealtimeServerEvent.Unknown(type)
        }
    }

    internal fun isAuthError(code: String?, message: String): Boolean {
        if (code == "invalid_api_key" || code == "invalid_authentication") return true
        val lowered = message.lowercase(Locale.ROOT)
        return lowered.contains("401") ||
            lowered.contains("auth") ||
            lowered.contains("api key") ||
            lowered.contains("api_key")
    }

    private fun JsonObject.string(key: String): String? =
        (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.content
}
