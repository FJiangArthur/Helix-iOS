package com.artjiang.helix.data

import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.conversate.HelixMode
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.RealtimeEvents
import com.artjiang.helix.speech.TranscriptionSource
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The DataStore-backed flows need an Android Context; the raw-value parsing
 * they share is what decides the defaults, so that is what runs on the JVM.
 */
class SettingsRepositoryParsingTest {

    @Test
    fun `transcription source parses known names and defaults to device`() {
        assertEquals(TranscriptionSource.OPENAI_REALTIME, SettingsRepository.parseTranscriptionSource("OPENAI_REALTIME"))
        assertEquals(TranscriptionSource.OMI, SettingsRepository.parseTranscriptionSource("OMI"))
        assertEquals(TranscriptionSource.DEVICE, SettingsRepository.parseTranscriptionSource(null))
        assertEquals(TranscriptionSource.DEVICE, SettingsRepository.parseTranscriptionSource("whisper"))
        assertEquals(TranscriptionSource.DEVICE, SettingsRepository.parseTranscriptionSource(""))
    }

    @Test
    fun `question mode parses known names and defaults to auto-detect`() {
        assertEquals(QuestionMode.ON_DEMAND, SettingsRepository.parseQuestionMode("ON_DEMAND"))
        assertEquals(QuestionMode.AUTO_DETECT, SettingsRepository.parseQuestionMode("AUTO_DETECT"))
        assertEquals(QuestionMode.AUTO_DETECT, SettingsRepository.parseQuestionMode(null))
        assertEquals(QuestionMode.AUTO_DETECT, SettingsRepository.parseQuestionMode("manual"))
    }

    @Test
    fun `question sensitivity parses all levels and safely defaults to balanced`() {
        assertEquals(QuestionSensitivity.PRECISE, SettingsRepository.parseQuestionSensitivity("PRECISE"))
        assertEquals(QuestionSensitivity.BALANCED, SettingsRepository.parseQuestionSensitivity("BALANCED"))
        assertEquals(QuestionSensitivity.HIGH, SettingsRepository.parseQuestionSensitivity("HIGH"))
        assertEquals(QuestionSensitivity.BALANCED, SettingsRepository.parseQuestionSensitivity(null))
        assertEquals(QuestionSensitivity.BALANCED, SettingsRepository.parseQuestionSensitivity("aggressive"))
    }

    @Test
    fun `glasses toggles default to enabled when the key is missing`() {
        assertEquals(true, SettingsRepository.parseGlassesToggle(null))
        assertEquals(true, SettingsRepository.parseGlassesToggle(true))
        assertEquals(false, SettingsRepository.parseGlassesToggle(false))
    }

    @Test
    fun `notification whitelist sanitizes blanks padding and duplicates`() {
        assertEquals(emptySet<String>(), SettingsRepository.sanitizePackages(null))
        assertEquals(emptySet<String>(), SettingsRepository.sanitizePackages(setOf("", "   ")))
        assertEquals(
            setOf("com.example.chat"),
            SettingsRepository.sanitizePackages(setOf(" com.example.chat ", "com.example.chat", "")),
        )
        assertEquals(
            setOf("com.example.chat", "com.example.mail"),
            SettingsRepository.sanitizePackages(setOf("com.example.chat", "com.example.mail")),
        )
    }

    @Test
    fun `transcription model trims and defaults to gpt-live-transcribe`() {
        assertEquals("gpt-live-transcribe", RealtimeEvents.DEFAULT_MODEL)
        assertEquals(RealtimeEvents.DEFAULT_MODEL, SettingsRepository.parseTranscriptionModel(null))
        assertEquals(RealtimeEvents.DEFAULT_MODEL, SettingsRepository.parseTranscriptionModel("   "))
        assertEquals("whisper-1", SettingsRepository.parseTranscriptionModel("  whisper-1 "))
    }

    @Test
    fun `helix mode parses known names and otherwise follows the transcription source`() {
        assertEquals(HelixMode.DISPLAY_ONLY, SettingsRepository.parseHelixMode("DISPLAY_ONLY", TranscriptionSource.OMI))
        assertEquals(HelixMode.OMI, SettingsRepository.parseHelixMode(null, TranscriptionSource.OMI))
        assertEquals(HelixMode.PHONE_MIC, SettingsRepository.parseHelixMode(null, TranscriptionSource.DEVICE))
        assertEquals(HelixMode.PHONE_MIC, SettingsRepository.parseHelixMode("GLASSES", TranscriptionSource.OPENAI_REALTIME))
    }

    @Test
    fun `conversate display prefs clamp to the contract ranges`() {
        assertEquals(5, SettingsRepository.parseCaptionLines(null))
        assertEquals(2, SettingsRepository.parseCaptionLines(1))
        assertEquals(4, SettingsRepository.parseCaptionLines(4))
        assertEquals(5, SettingsRepository.parseCaptionLines(9))
        assertEquals(3, SettingsRepository.parseBrightness(null))
        assertEquals(1, SettingsRepository.parseBrightness(0))
        assertEquals(4, SettingsRepository.parseBrightness(7))
    }
}
