package com.artjiang.helix

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Bounded answer-work queue with concurrent preparation and ordered commits.
 *
 * Provider calls are the slow part and must not form a global FIFO: a later
 * fast question is allowed to finish while an earlier provider is still
 * thinking. The returned commit closures are nevertheless invoked strictly in
 * submission order, so feed/HUD state cannot reorder the conversation. New
 * conversation cancellation invalidates both stages as one epoch.
 */
internal class OrderedAnswerQueue(
    private val scope: CoroutineScope,
    private val maxPending: Int,
    private val maxConcurrent: Int = 1,
    private val onTaskStarted: (epoch: Long) -> Unit = {},
    private val onTaskFinished: (epoch: Long) -> Unit = {},
    private val onTaskFailure: (Throwable) -> Unit = {},
) {
    init {
        require(maxPending > 0) { "maxPending must be positive" }
        require(maxConcurrent > 0) { "maxConcurrent must be positive" }
    }

    private data class WorkItem(
        val sequence: Long,
        val epoch: Long,
        val prepare: suspend () -> (suspend () -> Unit),
    )

    private sealed interface Outcome {
        data class Ready(val commit: suspend () -> Unit) : Outcome
        data class Failed(val error: Throwable) : Outcome
    }

    private val lock = Any()
    private val waiting = ArrayDeque<WorkItem>()
    private val running = LinkedHashMap<Long, Job>()
    private val completed = mutableMapOf<Long, Outcome>()
    private var committer: Job? = null
    private var epoch = 0L
    private var nextSequence = 0L
    private var nextCommitSequence = 0L

    /** Compatibility shape for work that has no separate publication step. */
    fun submit(block: suspend () -> Unit): Boolean = submitPrepared {
        block()
        suspend {}
    }

    /**
     * Runs [prepare] in the bounded concurrent stage. Its returned closure is
     * the externally visible state mutation and runs in submission order.
     */
    fun submitPrepared(prepare: suspend () -> (suspend () -> Unit)): Boolean = synchronized(lock) {
        val outstanding = waiting.size + running.size + completed.size
        if (outstanding >= maxPending + maxConcurrent) return false

        val item = WorkItem(nextSequence++, epoch, prepare)
        waiting.addLast(item)
        launchWaitingLocked()
        true
    }

    /** Cancels active work and drops waiting/completed commits at a conversation boundary. */
    fun cancelAll() {
        val jobs = synchronized(lock) {
            epoch += 1
            waiting.clear()
            completed.clear()
            nextCommitSequence = nextSequence
            val active = running.values.toList() + listOfNotNull(committer)
            running.clear()
            committer = null
            active
        }
        jobs.forEach { it.cancel() }
    }

    /** Caller holds [lock]. */
    private fun launchWaitingLocked() {
        while (running.size < maxConcurrent && waiting.isNotEmpty()) {
            val item = waiting.removeFirst()
            val job = scope.launch(start = CoroutineStart.LAZY) { execute(item) }
            running[item.sequence] = job
            job.start()
        }
    }

    private suspend fun execute(item: WorkItem) {
        var started = false
        val outcome = try {
            onTaskStarted(item.epoch)
            started = true
            Outcome.Ready(item.prepare())
        } catch (cancelled: CancellationException) {
            if (started) onTaskFinished(item.epoch)
            throw cancelled
        } catch (error: Throwable) {
            Outcome.Failed(error)
        }

        synchronized(lock) {
            running.remove(item.sequence)
            if (item.epoch == epoch) {
                completed[item.sequence] = outcome
                launchWaitingLocked()
                launchCommitterLocked()
            } else if (started) {
                // The task crossed an epoch boundary without observing
                // cancellation until after it returned.
                onTaskFinished(item.epoch)
            }
        }
    }

    /** Caller holds [lock]. */
    private fun launchCommitterLocked() {
        if (committer != null || completed[nextCommitSequence] == null) return
        val token = epoch
        val job = scope.launch(start = CoroutineStart.LAZY) { drainCommits(token) }
        committer = job
        job.start()
    }

    private suspend fun drainCommits(token: Long) {
        while (true) {
            val outcome = synchronized(lock) {
                if (token != epoch) return
                completed.remove(nextCommitSequence).also {
                    if (it == null) committer = null
                }
            } ?: return

            try {
                when (outcome) {
                    is Outcome.Ready -> outcome.commit()
                    is Outcome.Failed -> onTaskFailure(outcome.error)
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                onTaskFailure(error)
            } finally {
                onTaskFinished(token)
            }

            synchronized(lock) {
                if (token != epoch) return
                nextCommitSequence += 1
            }
        }
    }
}
