package com.artjiang.helix

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class OrderedAnswerQueueTest {

    @Test
    fun `later fast provider prepares while first is blocked but commits stay ordered`() = runTest {
        val firstStarted = CompletableDeferred<Unit>()
        val releaseFirst = CompletableDeferred<Unit>()
        val secondPrepared = CompletableDeferred<Unit>()
        val committed = mutableListOf<String>()
        val queue = OrderedAnswerQueue(scope = this, maxPending = 4, maxConcurrent = 2)

        assertTrue(queue.submitPrepared {
            firstStarted.complete(Unit)
            releaseFirst.await()
            suspend { committed += "first" }
        })
        firstStarted.await()
        assertTrue(queue.submitPrepared {
            secondPrepared.complete(Unit)
            suspend { committed += "second" }
        })

        secondPrepared.await()
        runCurrent()
        assertEquals("a completed later answer must wait only to publish", emptyList<String>(), committed)

        releaseFirst.complete(Unit)
        advanceUntilIdle()
        assertEquals(listOf("first", "second"), committed)
    }

    @Test
    fun `later finalized transcript waits and cannot cancel an earlier valid answer`() = runTest {
        val firstStarted = CompletableDeferred<Unit>()
        val finishFirst = CompletableDeferred<Unit>()
        val delivered = mutableListOf<String>()
        val queue = OrderedAnswerQueue(scope = this, maxPending = 4)

        assertTrue(queue.submit {
            firstStarted.complete(Unit)
            finishFirst.await()
            delivered += "first question answered"
        })
        firstStarted.await()
        assertTrue(queue.submit { delivered += "second question answered" })
        runCurrent()

        assertEquals("the first answer must remain active, not be cancelled", emptyList<String>(), delivered)
        finishFirst.complete(Unit)
        advanceUntilIdle()

        assertEquals(
            listOf("first question answered", "second question answered"),
            delivered,
        )
    }

    @Test
    fun `bounded queue preserves accepted work and visibly rejects overflow`() = runTest {
        val release = CompletableDeferred<Unit>()
        val delivered = mutableListOf<String>()
        val queue = OrderedAnswerQueue(scope = this, maxPending = 1)

        assertTrue(queue.submit { release.await(); delivered += "active" })
        runCurrent()
        assertTrue(queue.submit { delivered += "queued" })
        assertFalse(queue.submit { delivered += "silently lost" })

        release.complete(Unit)
        advanceUntilIdle()
        assertEquals(listOf("active", "queued"), delivered)
    }

    @Test
    fun `new conversation cancels active and queued answers`() = runTest {
        val release = CompletableDeferred<Unit>()
        val delivered = mutableListOf<String>()
        val queue = OrderedAnswerQueue(scope = this, maxPending = 4)

        queue.submit { release.await(); delivered += "old active" }
        runCurrent()
        queue.submit { delivered += "old queued" }
        queue.cancelAll()
        release.complete(Unit)
        advanceUntilIdle()

        assertEquals(emptyList<String>(), delivered)
    }

    @Test
    fun `failed answer clears thinking and stream state before the next queued answer`() = runTest {
        var answering = false
        var thinking = false
        var stream = ""
        var failures = 0
        val delivered = mutableListOf<String>()
        val queue = OrderedAnswerQueue(
            scope = this,
            maxPending = 4,
            onTaskStarted = {
                answering = true
                thinking = true
                stream = ""
            },
            onTaskFinished = {
                answering = false
                thinking = false
                stream = ""
            },
            onTaskFailure = { failures += 1 },
        )

        queue.submit {
            stream = "partial failure"
            throw IllegalStateException("provider failed")
        }
        queue.submit {
            assertTrue(answering)
            assertTrue(thinking)
            assertEquals("a new answer must not inherit failed tokens", "", stream)
            delivered += "next answer"
        }
        advanceUntilIdle()

        assertEquals(1, failures)
        assertEquals(listOf("next answer"), delivered)
        assertFalse(answering)
        assertFalse(thinking)
        assertEquals("", stream)
    }
}
