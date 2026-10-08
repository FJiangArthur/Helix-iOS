package com.artjiang.helix.conversate

import com.artjiang.helix.g1.G1CommandEncoder
import com.artjiang.helix.speech.TranscriptionSource
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HelixModePolicyTest {
    @Test
    fun `phone mic keeps the user's non-Omi source`() {
        assertEquals(TranscriptionSource.DEVICE, HelixModePolicy.sourceFor(HelixMode.PHONE_MIC, TranscriptionSource.DEVICE))
        assertEquals(
            TranscriptionSource.OPENAI_REALTIME,
            HelixModePolicy.sourceFor(HelixMode.PHONE_MIC, TranscriptionSource.OPENAI_REALTIME),
        )
    }

    @Test
    fun `phone mic leaves Omi for OpenAI realtime`() {
        assertEquals(TranscriptionSource.OPENAI_REALTIME, HelixModePolicy.sourceFor(HelixMode.PHONE_MIC, TranscriptionSource.OMI))
    }

    @Test
    fun `omi mode uses the Omi source and display only has none`() {
        assertEquals(TranscriptionSource.OMI, HelixModePolicy.sourceFor(HelixMode.OMI, TranscriptionSource.DEVICE))
        assertNull(HelixModePolicy.sourceFor(HelixMode.DISPLAY_ONLY, TranscriptionSource.DEVICE))
    }

    @Test
    fun `only display only forbids listening`() {
        assertFalse(HelixModePolicy.canListen(HelixMode.DISPLAY_ONLY))
        assertTrue(HelixModePolicy.canListen(HelixMode.PHONE_MIC))
        assertTrue(HelixModePolicy.canListen(HelixMode.OMI))
    }

    @Test
    fun `brightness levels map to the contract G1 bytes`() {
        assertEquals(listOf(10, 20, 30, 42), (1..4).map(ConversatePrefs::g1BrightnessByte))
        assertEquals(10, ConversatePrefs.g1BrightnessByte(0))
        assertArrayEquals(
            byteArrayOf(0x01, 42, 0x00),
            G1CommandEncoder.brightness(ConversatePrefs.g1BrightnessByte(4), autoBrightness = false),
        )
    }
}
