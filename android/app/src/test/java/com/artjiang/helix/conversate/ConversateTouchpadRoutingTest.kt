package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Test

class ConversateTouchpadRoutingTest {
    @Test
    fun `every touchpad index is owned by conversate when enabled`() {
        listOf(0, 1, 23, 24).forEach { idx ->
            assertEquals("idx $idx", TouchpadOwner.CONVERSATE, TouchpadOwner.route(idx, conversateEnabled = true))
        }
    }

    @Test
    fun `legacy owns everything when disabled`() {
        listOf(0, 1, 23, 24).forEach { idx ->
            assertEquals("idx $idx", TouchpadOwner.LEGACY, TouchpadOwner.route(idx, conversateEnabled = false))
        }
    }
}
