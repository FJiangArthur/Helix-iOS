package com.artjiang.helix

/**
 * Conversation epoch shared by the bridge and its ordered provider queue.
 * A provider may ignore coroutine cancellation; the epoch check is therefore
 * the final guard that keeps an old listening session out of a restarted one.
 */
internal class AnswerSessionBoundary(private val queue: OrderedAnswerQueue) {
    private var epoch = 0L

    fun capture(): Long = epoch

    fun isCurrent(captured: Long): Boolean = captured == epoch

    fun invalidateForListeningStart() {
        epoch += 1
        queue.cancelAll()
    }
}
