package com.artjiang.helix

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AnswerSessionBoundaryTest {

    @Test
    fun `stop start boundary rejects an old provider that returns after cancellation`() = runTest {
        val releaseOld = CompletableDeferred<Unit>()
        val oldStarted = CompletableDeferred<Unit>()
        val delivered = mutableListOf<String>()
        val queue = OrderedAnswerQueue(scope = this, maxPending = 4, maxConcurrent = 2)
        val boundary = AnswerSessionBoundary(queue)
        val oldEpoch = boundary.capture()

        queue.submitPrepared {
            oldStarted.complete(Unit)
            withContext(NonCancellable) { releaseOld.await() }
            suspend { if (boundary.isCurrent(oldEpoch)) delivered += "old session" }
        }
        oldStarted.await()

        boundary.invalidateForListeningStart()
        val newEpoch = boundary.capture()
        queue.submitPrepared {
            suspend { if (boundary.isCurrent(newEpoch)) delivered += "new session" }
        }
        runCurrent()
        releaseOld.complete(Unit)
        advanceUntilIdle()

        assertEquals(listOf("new session"), delivered)
    }
}
