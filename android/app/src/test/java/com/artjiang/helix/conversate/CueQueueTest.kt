package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CueQueueTest {
    private fun cue(id: Long, type: CueType, at: Long = 0) = Cue(id, type, "t$id", "b$id", createdAtMillis = at)

    @Test
    fun `poll returns highest priority, fifo within priority`() {
        val q = CueQueue()
        q.offer(cue(1, CueType.SUGGESTION, 0), 0)
        q.offer(cue(2, CueType.CONCEPT, 1), 1)
        q.offer(cue(3, CueType.BIO, 2), 2)
        assertEquals(2L, q.poll(3)?.id)
        assertEquals(3L, q.poll(3)?.id)
        assertEquals(1L, q.poll(3)?.id)
        assertNull(q.poll(3))
    }

    @Test
    fun `overflow evicts oldest lowest priority`() {
        val q = CueQueue(capacity = 3)
        q.offer(cue(1, CueType.SUGGESTION, 0), 0)
        q.offer(cue(2, CueType.SUGGESTION, 1), 1)
        q.offer(cue(3, CueType.CONCEPT, 2), 2)
        q.offer(cue(4, CueType.CONCEPT, 3), 3)
        assertEquals(3, q.size)
        assertEquals(listOf(3L, 4L, 2L), generateSequence { q.poll(4) }.map { it.id }.toList())
    }

    @Test
    fun `answer is never evicted and may exceed capacity`() {
        val q = CueQueue(capacity = 3)
        repeat(3) { q.offer(cue(it.toLong(), CueType.ANSWER, it.toLong()), it.toLong()) }
        q.offer(cue(9, CueType.ANSWER, 9), 9)
        assertEquals(4, q.size)
        q.offer(cue(10, CueType.CONCEPT, 10), 10)
        assertEquals(4, q.size)
    }

    @Test
    fun `stale cues are dropped`() {
        val q = CueQueue(staleMillis = 90_000)
        q.offer(cue(1, CueType.CONCEPT, 0), 0)
        assertEquals(0, q.count(90_001))
        assertNull(q.poll(90_001))
    }
}
