package com.artjiang.helix.speech

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.data.OmiLiveSegment
import com.artjiang.helix.data.OmiLiveService
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class OmiTranscriptSourceTest {

    private fun segment(text: String, speaker: String? = "SPEAKER_01", isUser: Boolean = false) =
        OmiLiveSegment(seq = 1, text = text, speaker = speaker, isUser = isUser, sessionId = "s")

    private fun TestScope.source(feedUrl: String? = "https://relay.example/feed/abc"): Pair<OmiTranscriptSource, OmiLiveService> {
        val service = OmiLiveService(this)
        val source = OmiTranscriptSource(service, this, feedUrl = { feedUrl })
        return source to service
    }

    @Test
    fun `terminal punctuation flushes the utterance immediately`() = runTest {
        val (source, service) = source()
        val finals = mutableListOf<TranscriptSegment>()
        source.onSegment = { if (it.isFinal) finals += it }

        service.onSegment!!.invoke(segment("What is the"))
        service.onSegment!!.invoke(segment("plan for Tuesday?"))

        assertEquals(listOf("What is the plan for Tuesday?"), finals.map { it.text })
        assertEquals("", source.partialTranscript.value)
    }

    @Test
    fun `quiet gap flushes a non-terminal utterance`() = runTest {
        val (source, service) = source()
        val finals = mutableListOf<TranscriptSegment>()
        source.onSegment = { if (it.isFinal) finals += it }

        service.onSegment!!.invoke(segment("so we launch"))
        runCurrent()
        assertTrue(finals.isEmpty())
        assertEquals("so we launch", source.partialTranscript.value)

        advanceTimeBy(OmiTranscriptSource.DEFAULT_GAP_MILLIS)
        runCurrent()
        assertEquals(listOf("so we launch"), finals.map { it.text })
        assertEquals("", source.partialTranscript.value)
    }

    @Test
    fun `a new fragment restarts the gap timer`() = runTest {
        val (source, service) = source()
        val finals = mutableListOf<TranscriptSegment>()
        source.onSegment = { if (it.isFinal) finals += it }

        service.onSegment!!.invoke(segment("first part"))
        advanceTimeBy(1_000)
        service.onSegment!!.invoke(segment("second part"))
        advanceTimeBy(1_000)
        runCurrent()
        assertTrue("timer should have restarted", finals.isEmpty())
        assertEquals("first part second part", source.partialTranscript.value)

        advanceTimeBy(600)
        runCurrent()
        assertEquals(listOf("first part second part"), finals.map { it.text })
    }

    @Test
    fun `partials are emitted for the running utterance and raw segments keep the speaker`() = runTest {
        val (source, service) = source()
        val partials = mutableListOf<String>()
        val raw = mutableListOf<OmiLiveSegment>()
        source.onSegment = { if (!it.isFinal) partials += it.text }
        source.onRawSegment = { raw += it }

        service.onSegment!!.invoke(segment("hello", speaker = "SPEAKER_02"))
        service.onSegment!!.invoke(segment("there."))

        assertEquals(listOf("hello", "hello there."), partials)
        assertEquals(listOf("SPEAKER_02", "SPEAKER_01"), raw.map { it.speaker })
    }

    @Test
    fun `consecutive utterances from different speakers keep their own attribution on flush`() = runTest {
        val (source, service) = source()
        val finals = mutableListOf<TranscriptSegment>()
        source.onSegment = { if (it.isFinal) finals += it }

        // First utterance: SPEAKER_01, not the user. Terminal punctuation flushes it.
        service.onSegment!!.invoke(segment("Hello there.", speaker = "SPEAKER_01", isUser = false))

        // Second utterance: a different speaker entirely — the wearer. Its second
        // fragment carries a bogus relay-reported speaker; the coalesced final must
        // stay pinned to the FIRST fragment's attribution (the one that opened this
        // utterance), not bleed from the prior utterance nor get overwritten mid-way.
        service.onSegment!!.invoke(segment("Hi,", speaker = null, isUser = true))
        service.onSegment!!.invoke(segment("I'm good.", speaker = "SPEAKER_99", isUser = false))

        assertEquals(2, finals.size)
        assertEquals("SPEAKER_01", finals[0].speaker)
        assertFalse(finals[0].isUser)
        assertEquals(null, finals[1].speaker)
        assertTrue(finals[1].isUser)
    }

    @Test
    fun `stop flushes whatever is pending`() = runTest {
        val (source, service) = source()
        val finals = mutableListOf<TranscriptSegment>()
        source.onSegment = { if (it.isFinal) finals += it }

        service.onSegment!!.invoke(segment("half a thought"))
        source.stop()
        assertEquals(listOf("half a thought"), finals.map { it.text })
        assertFalse(source.isListening.value)
    }

    @Test
    fun `missing relay url is an error without starting`() = runTest {
        val (source, _) = source(feedUrl = null)
        source.start()
        assertFalse(source.isListening.value)
        assertEquals("No relay URL configured.", source.errorMessage.value)

        source.clearError()
        assertEquals("", source.errorMessage.value)
    }

    @Test
    fun `blank relay url is also an error`() = runTest {
        val (source, _) = source(feedUrl = "   ")
        source.start()
        assertFalse(source.isListening.value)
        assertEquals("No relay URL configured.", source.errorMessage.value)
    }

    @Test
    fun `endsUtterance recognises latin and cjk terminal punctuation`() {
        assertTrue(OmiTranscriptSource.endsUtterance("Done."))
        assertTrue(OmiTranscriptSource.endsUtterance("Really?  "))
        assertTrue(OmiTranscriptSource.endsUtterance("好的。"))
        assertTrue(OmiTranscriptSource.endsUtterance("什么？"))
        assertFalse(OmiTranscriptSource.endsUtterance("and then"))
        assertFalse(OmiTranscriptSource.endsUtterance(""))
    }
}
