package com.artjiang.helix.ui

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Test

/** Boundary tests for the width-class bucketing (pure Dp math, no Android). */
class AdaptiveLayoutTest {

    @Test
    fun `below 380dp is Narrow`() {
        assertEquals(HelixWidthClass.Narrow, helixWidthClass(0.dp))
        assertEquals(HelixWidthClass.Narrow, helixWidthClass(296.dp)) // Fold cover usable
        assertEquals(HelixWidthClass.Narrow, helixWidthClass(379.dp))
        assertEquals(HelixWidthClass.Narrow, helixWidthClass(379.9f.dp))
    }

    @Test
    fun `380dp up to 599dp is Standard`() {
        assertEquals(HelixWidthClass.Standard, helixWidthClass(380.dp))
        assertEquals(HelixWidthClass.Standard, helixWidthClass(411.dp)) // typical phone
        assertEquals(HelixWidthClass.Standard, helixWidthClass(599.dp))
        assertEquals(HelixWidthClass.Standard, helixWidthClass(599.9f.dp))
    }

    @Test
    fun `600dp and above is Wide`() {
        assertEquals(HelixWidthClass.Wide, helixWidthClass(600.dp))
        assertEquals(HelixWidthClass.Wide, helixWidthClass(840.dp)) // Fold inner
        assertEquals(HelixWidthClass.Wide, helixWidthClass(1280.dp))
    }
}
