package com.artjiang.helix.speech

import com.artjiang.helix.core.TranscriptSegment
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptSourceSwitchTest {

    private class FakeSource(private val startError: String? = null) : TranscriptSource {
        val listening = MutableStateFlow(false)
        override val isListening: StateFlow<Boolean> = listening.asStateFlow()
        val partial = MutableStateFlow("")
        override val partialTranscript: StateFlow<String> = partial.asStateFlow()
        val error = MutableStateFlow("")
        override val errorMessage: StateFlow<String> = error.asStateFlow()
        override var onSegment: ((TranscriptSegment) -> Unit)? = null
        var startCount = 0
        var stopCount = 0

        override fun start() {
            startCount += 1
            if (startError != null) {
                error.value = startError
                return
            }
            listening.value = true
        }

        override fun stop() {
            stopCount += 1
            listening.value = false
            partial.value = ""
        }

        override fun clearError() {
            error.value = ""
        }

        /** Simulates a failure from inside the source (network drop, recognizer error). */
        fun failInternally(message: String) {
            listening.value = false
            error.value = message
        }

        fun emit(text: String, final: Boolean) {
            onSegment?.invoke(TranscriptSegment(text, final, 0L))
        }
    }

    private val device = FakeSource()
    private val realtime = FakeSource()
    private val omi = FakeSource(startError = "No relay URL configured.")

    private val switch = TranscriptSourceSwitch(
        mapOf(
            TranscriptionSource.DEVICE to device,
            TranscriptionSource.OPENAI_REALTIME to realtime,
            TranscriptionSource.OMI to omi,
        ),
        CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `start stops the other sources first and exposes the active one`() {
        switch.start(TranscriptionSource.DEVICE)
        assertTrue(device.isListening.value)
        assertEquals(TranscriptionSource.DEVICE, switch.active.value)
        assertTrue(switch.isListening.value)

        switch.start(TranscriptionSource.OPENAI_REALTIME)
        assertFalse(device.isListening.value)
        assertEquals(1, device.stopCount)
        assertTrue(realtime.isListening.value)
        assertEquals(TranscriptionSource.OPENAI_REALTIME, switch.active.value)
        assertTrue(switch.isListening.value)
    }

    @Test
    fun `stop is idempotent and clears the active source`() {
        switch.start(TranscriptionSource.DEVICE)
        switch.stop()
        switch.stop()
        assertFalse(switch.isListening.value)
        assertNull(switch.active.value)
        assertNull(switch.selected.value)
        assertEquals(2, device.stopCount)
    }

    @Test
    fun `partial transcript follows the active source`() {
        switch.start(TranscriptionSource.OPENAI_REALTIME)
        realtime.partial.value = "hello wor"
        device.partial.value = "stale device text"
        assertEquals("hello wor", switch.partialTranscript.value)

        switch.stop()
        assertEquals("", switch.partialTranscript.value)
    }

    @Test
    fun `active goes null when the source stops on its own`() {
        switch.start(TranscriptionSource.OPENAI_REALTIME)
        realtime.failInternally("OpenAI rejected the API key (401). Check the key in Settings.")
        assertNull(switch.active.value)
        assertFalse(switch.isListening.value)
        assertEquals(TranscriptionSource.OPENAI_REALTIME, switch.selected.value)
        assertEquals("OpenAI rejected the API key (401). Check the key in Settings.", switch.errorMessage.value)
    }

    @Test
    fun `error message is the last-started source's and clears when a different source starts`() {
        switch.start(TranscriptionSource.OMI)
        assertFalse(switch.isListening.value)
        assertEquals("No relay URL configured.", switch.errorMessage.value)

        // Another source's stale error must not leak through.
        device.error.value = "old device error"
        assertEquals("No relay URL configured.", switch.errorMessage.value)

        switch.start(TranscriptionSource.DEVICE)
        assertEquals("", omi.errorMessage.value)
        assertEquals("old device error", switch.errorMessage.value)

        switch.clearError()
        assertEquals("", switch.errorMessage.value)
    }

    @Test
    fun `restarting the same failed source keeps its fresh error`() {
        switch.start(TranscriptionSource.OMI)
        switch.start(TranscriptionSource.OMI)
        assertEquals(2, omi.startCount)
        assertEquals("No relay URL configured.", switch.errorMessage.value)
    }

    @Test
    fun `segments from every source fan in`() {
        val received = mutableListOf<Pair<String, Boolean>>()
        switch.onSegment = { received += it.text to it.isFinal }

        switch.start(TranscriptionSource.DEVICE)
        device.emit("from device", true)
        switch.start(TranscriptionSource.OPENAI_REALTIME)
        realtime.emit("from realtime", false)

        assertEquals(listOf("from device" to true, "from realtime" to false), received)
    }

    @Test
    fun `toggle starts when idle and stops when listening`() {
        switch.toggle(TranscriptionSource.DEVICE)
        assertTrue(switch.isListening.value)
        switch.toggle(TranscriptionSource.DEVICE)
        assertFalse(switch.isListening.value)
    }
}
