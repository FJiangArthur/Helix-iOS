package com.artjiang.helix.ui

import com.artjiang.helix.conversate.HelixMode
import com.artjiang.helix.ring.RingLinkState
import org.junit.Assert.assertEquals
import org.junit.Test

class ConversateSummaryTest {
    @Test
    fun `summary is one compact line for every state`() {
        assertEquals("Off - open Controls to turn on", conversateSummary(false, false, HelixMode.PHONE_MIC, false, RingLinkState.OFF))
        assertEquals("Ready · Phone mic", conversateSummary(true, false, HelixMode.PHONE_MIC, false, RingLinkState.OFF))
        assertEquals("Live · Omi · Ring connected", conversateSummary(true, true, HelixMode.OMI, true, RingLinkState.CONNECTED))
        assertEquals("Ready · Display only · Ring waiting", conversateSummary(true, false, HelixMode.DISPLAY_ONLY, true, RingLinkState.CONNECTING))
    }
}
