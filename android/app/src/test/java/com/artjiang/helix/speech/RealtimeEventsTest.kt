package com.artjiang.helix.speech

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class RealtimeEventsTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `session update uses the nested transcription schema`() {
        val root = json.parseToJsonElement(
            RealtimeEvents.sessionUpdate(model = "gpt-4o-mini-transcribe", language = "de"),
        ).jsonObject
        assertEquals("session.update", root["type"]!!.jsonPrimitive.content)

        val session = root["session"]!!.jsonObject
        assertEquals("transcription", session["type"]!!.jsonPrimitive.content)
        val input = session["audio"]!!.jsonObject["input"]!!.jsonObject

        val format = input["format"]!!.jsonObject
        assertEquals("audio/pcm", format["type"]!!.jsonPrimitive.content)
        assertEquals(24000, format["rate"]!!.jsonPrimitive.content.toInt())

        val transcription = input["transcription"]!!.jsonObject
        assertEquals("gpt-4o-mini-transcribe", transcription["model"]!!.jsonPrimitive.content)
        assertEquals("de", transcription["language"]!!.jsonPrimitive.content)

        val vad = input["turn_detection"]!!.jsonObject
        assertEquals("server_vad", vad["type"]!!.jsonPrimitive.content)
        assertEquals(0.35, vad["threshold"]!!.jsonPrimitive.content.toDouble(), 1e-9)
        assertEquals(500, vad["prefix_padding_ms"]!!.jsonPrimitive.content.toInt())
        assertEquals(1000, vad["silence_duration_ms"]!!.jsonPrimitive.content.toInt())

        // The stale flat shape must not be emitted.
        assertFalse(root.containsKey("input_audio_format"))
        assertFalse(root.toString().contains("transcription_session"))
    }

    @Test
    fun `live transcription models omit turn_detection`() {
        // The GA server rejects server_vad for gpt-live-transcribe:
        // "turn detection is not supported for this model".
        val root = json.parseToJsonElement(
            RealtimeEvents.sessionUpdate(model = RealtimeEvents.DEFAULT_MODEL, language = "en"),
        ).jsonObject
        val input = root["session"]!!.jsonObject["audio"]!!.jsonObject["input"]!!.jsonObject
        assertFalse(input.containsKey("turn_detection"))
        assertFalse(RealtimeEvents.supportsServerVad("gpt-live-transcribe"))
        assertTrue(RealtimeEvents.supportsServerVad("gpt-4o-mini-transcribe"))
        assertTrue(RealtimeEvents.supportsServerVad("whisper-1"))
    }

    @Test
    fun `blank model falls back to the default`() {
        val root = json.parseToJsonElement(RealtimeEvents.sessionUpdate(model = "  ")).jsonObject
        val model = root["session"]!!.jsonObject["audio"]!!.jsonObject["input"]!!.jsonObject["transcription"]!!
            .jsonObject["model"]!!.jsonPrimitive.content
        assertEquals("gpt-live-transcribe", model)
        assertEquals("gpt-live-transcribe", RealtimeEvents.DEFAULT_MODEL)
    }

    @Test
    fun `audio frames are compact templates`() {
        assertEquals(
            """{"type":"input_audio_buffer.append","audio":"AAAA"}""",
            RealtimeEvents.audioAppend("AAAA"),
        )
        assertEquals("""{"type":"input_audio_buffer.commit"}""", RealtimeEvents.audioCommit())
        assertEquals("""{"type":"input_audio_buffer.clear"}""", RealtimeEvents.audioClear())
    }

    @Test
    fun `parses session ready for both event families`() {
        for (type in listOf(
            "session.created", "session.updated",
            "transcription_session.created", "transcription_session.updated",
        )) {
            assertEquals(type, RealtimeServerEvent.SessionReady, RealtimeEvents.parse("""{"type":"$type","session":{}}"""))
        }
    }

    @Test
    fun `parses transcript delta completed and failed`() {
        assertEquals(
            RealtimeServerEvent.TranscriptDelta("item_1", "Hel"),
            RealtimeEvents.parse(
                """{"type":"conversation.item.input_audio_transcription.delta","item_id":"item_1","delta":"Hel"}""",
            ),
        )
        assertEquals(
            RealtimeServerEvent.TranscriptCompleted("item_1", "Hello there."),
            RealtimeEvents.parse(
                """{"type":"conversation.item.input_audio_transcription.completed","item_id":"item_1","transcript":"Hello there."}""",
            ),
        )
        assertEquals(
            RealtimeServerEvent.TranscriptFailed("audio too short"),
            RealtimeEvents.parse(
                """{"type":"conversation.item.input_audio_transcription.failed","error":{"message":"audio too short"}}""",
            ),
        )
    }

    @Test
    fun `error events flag auth failures`() {
        val byCode = RealtimeEvents.parse(
            """{"type":"error","error":{"type":"invalid_request_error","code":"invalid_api_key","message":"Incorrect API key provided"}}""",
        ) as RealtimeServerEvent.ApiError
        assertTrue(byCode.isAuth)
        assertEquals("invalid_api_key", byCode.code)

        val byMessage = RealtimeEvents.parse(
            """{"type":"error","error":{"message":"Unauthorized (401)"}}""",
        ) as RealtimeServerEvent.ApiError
        assertTrue(byMessage.isAuth)

        val other = RealtimeEvents.parse(
            """{"type":"error","error":{"code":"input_audio_buffer_commit_empty","message":"buffer too small"}}""",
        ) as RealtimeServerEvent.ApiError
        assertFalse(other.isAuth)
        assertEquals("buffer too small", other.message)
    }

    @Test
    fun `unknown and malformed payloads are harmless`() {
        assertEquals(RealtimeServerEvent.Unknown("rate_limits.updated"), RealtimeEvents.parse("""{"type":"rate_limits.updated"}"""))
        assertEquals(RealtimeServerEvent.Unknown(""), RealtimeEvents.parse("not json"))
        assertEquals(RealtimeServerEvent.Unknown(""), RealtimeEvents.parse("[1,2]"))
    }

    @Test
    fun `language codes map supported locales and fall back to english`() {
        assertEquals("zh", RealtimeEvents.languageCode(Locale.SIMPLIFIED_CHINESE))
        assertEquals("de", RealtimeEvents.languageCode(Locale.GERMANY))
        assertEquals("ja", RealtimeEvents.languageCode(Locale.JAPAN))
        assertEquals("en", RealtimeEvents.languageCode(Locale("pt", "BR")))
        assertEquals("en", RealtimeEvents.languageCode(Locale.ROOT))
    }
}
