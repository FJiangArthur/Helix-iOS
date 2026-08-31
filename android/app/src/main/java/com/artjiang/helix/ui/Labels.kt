// User-facing copy for core enums, in one place. Previously these lived
// inside AssistantScreen.kt while also being consumed by SettingsScreen —
// the display vocabulary for a domain enum shouldn't belong to whichever
// screen happened to be written first.
package com.artjiang.helix.ui

import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.TranscriptionSource

internal fun modeTitle(mode: ConversationMode): String = when (mode) {
    ConversationMode.ACTIVE -> "Active"
    ConversationMode.PASSIVE -> "Passive"
}

internal fun modeSummary(mode: ConversationMode): String = when (mode) {
    ConversationMode.ACTIVE -> "Concise answers for live conversation, shaped by the active skill."
    ConversationMode.PASSIVE -> "Quiet correction and context reminders."
}

/**
 * The model that answers: prefers the id the API actually reported for the
 * last answer (so a configured alias like `gpt-4.1` shows its resolved
 * snapshot), then the configured smart model.
 */
internal fun activeModel(
    settings: HelixSettings,
    providerKind: String,
    lastAnswer: AnswerResponse? = null,
): String =
    lastAnswer?.takeIf { it.providerKind.name == providerKind }?.model?.takeIf { it.isNotBlank() }
        ?: settings.providers[providerKind]?.smartModel
        ?: "built-in"

internal fun sourceTitle(source: TranscriptionSource): String = when (source) {
    TranscriptionSource.DEVICE -> "Device"
    TranscriptionSource.OPENAI_REALTIME -> "OpenAI Realtime"
    TranscriptionSource.OMI -> "Omi"
}

/** Short form for segmented rows, where "OpenAI Realtime" wraps; chips keep [sourceTitle]. */
internal fun sourceShortTitle(source: TranscriptionSource): String = when (source) {
    TranscriptionSource.DEVICE -> "Device"
    TranscriptionSource.OPENAI_REALTIME -> "OpenAI"
    TranscriptionSource.OMI -> "Omi"
}

internal fun sourceSummary(source: TranscriptionSource): String = when (source) {
    TranscriptionSource.DEVICE -> "Phone microphone via the system speech recognizer."
    TranscriptionSource.OPENAI_REALTIME -> "Phone microphone streamed to OpenAI realtime transcription."
    TranscriptionSource.OMI -> "Live transcript from your Omi device through the relay."
}

internal fun questionModeTitle(mode: QuestionMode): String = when (mode) {
    QuestionMode.AUTO_DETECT -> "Auto-detect"
    QuestionMode.ON_DEMAND -> "Ask on demand"
}

internal fun questionModeDetail(mode: QuestionMode): String = when (mode) {
    QuestionMode.AUTO_DETECT -> "Answer questions as they are heard."
    QuestionMode.ON_DEMAND ->
        "Stay quiet until you tap Ask now or the right touchpad, then answer the last minute of conversation."
}

internal fun questionSensitivityTitle(sensitivity: QuestionSensitivity): String = when (sensitivity) {
    QuestionSensitivity.PRECISE -> "Precise"
    QuestionSensitivity.BALANCED -> "Balanced"
    QuestionSensitivity.HIGH -> "High"
}

internal fun questionSensitivityDetail(sensitivity: QuestionSensitivity): String = when (sensitivity) {
    QuestionSensitivity.PRECISE ->
        "Explicit questions only. Examples: “Ready?” · “准备好了吗？” · “¿Está listo?”"
    QuestionSensitivity.BALANCED ->
        "Clear questions and direct asks. Examples: “Can you check?” · “你能帮我看一下” · “¿Puedes revisarlo?”"
    QuestionSensitivity.HIGH ->
        "Likely implied questions too. Examples: “I wonder what changed” · “有没有别的办法” · “Quizá puedas ayudarme”"
}
