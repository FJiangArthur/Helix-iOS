package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Test

class HudProbeTest {
    @Test
    fun `stats compute min median p90 max`() {
        val s = ProbeStats.of(listOf(100L, 300L, 200L, 400L, 500L, 600L, 700L, 800L, 900L, 1000L))
        assertEquals(10, s.count)
        assertEquals(100L, s.min)
        assertEquals(550L, s.median)
        assertEquals(900L, s.p90)
        assertEquals(1000L, s.max)
    }

    @Test
    fun `empty stats are zero`() {
        assertEquals(ProbeStats(0, 0, 0, 0, 0), ProbeStats.of(emptyList()))
    }

    @Test
    fun `log keeps newest entries with relative timestamps`() {
        var now = 1_000L
        val log = TouchpadProbeLog(capacity = 2, clock = { now })
        log.record("a"); now += 150; log.record("b"); now += 50; log.record("c")
        assertEquals(listOf("+150ms b", "+50ms c"), log.entries.value)
    }
}
