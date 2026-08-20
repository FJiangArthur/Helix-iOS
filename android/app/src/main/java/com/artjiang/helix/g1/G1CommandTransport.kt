// Port of the transport half of NativeHelix/Sources/HelixG1/G1Commands.swift
// (the `G1CommandTransport` actor), with the Swift implementation's known
// defects corrected — see "Deviations" below.
package com.artjiang.helix.g1

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout

/** Which lens a packet goes to. Dual BLE connections, left and right. */
enum class G1Side(val code: String) {
    LEFT("L"),
    RIGHT("R");

    companion object {
        val ALL: List<G1Side> = listOf(LEFT, RIGHT)
    }
}

/**
 * Writes raw bytes to one lens. The app shell backs this with the Android BLE
 * manager; tests use an in-memory fake.
 *
 * Returns true when the write was handed to the stack successfully.
 */
interface G1PacketWriter {
    suspend fun write(bytes: ByteArray, side: G1Side): Boolean
}

/** Delivery policy for a queued command. */
sealed interface G1AckPolicy {
    /** Fire and forget (heartbeat, text chunks — pacing only). */
    data object None : G1AckPolicy

    /** Wait for an ACK frame for [command] before proceeding. */
    data class Required(val command: Byte) : G1AckPolicy
}

/** One queued command with its delivery policy. */
data class G1Command(
    val bytes: ByteArray,
    val sides: List<G1Side> = G1Side.ALL,
    val ackPolicy: G1AckPolicy = G1AckPolicy.None,
    /** Pause after the write (inter-chunk pacing), in milliseconds. */
    val postDelayMillis: Long = G1CommandTransport.DEFAULT_CHUNK_PACING_MILLIS,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is G1Command) return false
        return bytes.contentEquals(other.bytes) &&
            sides == other.sides &&
            ackPolicy == other.ackPolicy &&
            postDelayMillis == other.postDelayMillis
    }

    override fun hashCode(): Int {
        var result = bytes.contentHashCode()
        result = 31 * result + sides.hashCode()
        result = 31 * result + ackPolicy.hashCode()
        result = 31 * result + postDelayMillis.hashCode()
        return result
    }
}

/** A record of one write, for tests and diagnostics. */
data class G1SentPacket(val bytes: ByteArray, val side: G1Side) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is G1SentPacket) return false
        return bytes.contentEquals(other.bytes) && side == other.side
    }

    override fun hashCode(): Int = 31 * bytes.contentHashCode() + side.hashCode()
}

/**
 * Serial, ACK-aware send path. Every outbound packet — config commands,
 * heartbeat, battery polls, and HUD text chunks — flows through this transport
 * so periodic timers can never interleave bytes into a multi-packet screen
 * write. ACK-required commands retry up to [MAX_ATTEMPTS] with [ackTimeoutMillis].
 *
 * ## Deviations from the Swift actor (deliberate bug fixes)
 *  1. **No unbounded task chain.** Swift chains each `send` onto a `tail` Task,
 *     which grows a retained task graph for the lifetime of the connection.
 *     Here a single [Mutex] serializes execution: FIFO with no accumulating
 *     structure, and no risk of a cancelled tail stranding successors.
 *  2. **The ACK timeout is cancelled when the ACK arrives.** Swift spawns a
 *     detached sleep per wait that keeps running after the ACK resolves and
 *     can clear a *later* waiter for the same side. [withTimeout] here is
 *     scoped to the wait and dies with it.
 *  3. **Waiters are keyed by side + generation token.** Swift keys only by
 *     side, so a stale inbound ACK — or the stale timeout from (2) — can
 *     resolve a waiter belonging to a different, newer command. Each wait
 *     takes a monotonically increasing generation; inbound frames and
 *     timeouts only resolve the waiter whose generation still matches.
 *  4. **`pendingAckCommand` is per-side**, so a dual-side ACK command cannot
 *     have one side's expectation clobber the other's.
 */
class G1CommandTransport(
    private val writer: G1PacketWriter,
    private val ackTimeoutMillis: Long = DEFAULT_ACK_TIMEOUT_MILLIS,
) {
    companion object {
        const val DEFAULT_ACK_TIMEOUT_MILLIS: Long = 5_000
        const val MAX_ATTEMPTS = 3
        const val RETRY_BACKOFF_MILLIS: Long = 100

        /** Default inter-chunk pacing for a multi-packet screen write. */
        const val DEFAULT_CHUNK_PACING_MILLIS: Long = 8

        /**
         * LOAD-BEARING: the 400 ms settle between finishing the left lens and
         * starting the right one. Removing or shortening this reliably breaks
         * streaming HUD updates on real hardware (the right lens drops or
         * garbles the page). Documented in
         * memory/reference_evenai_400ms_delay.md as
         * `Proto.evenAIInterSideDelay`. DO NOT REMOVE.
         */
        const val INTER_SIDE_DELAY_MILLIS: Long = 400
    }

    /** Serializes command execution — strict FIFO, no task chain. */
    private val queueMutex = Mutex()

    /** Guards waiter/expectation state against inbound frames on other threads. */
    private val stateMutex = Mutex()

    private data class AckWaiter(
        val generation: Long,
        val expectedCommand: Byte,
        val deferred: CompletableDeferred<Boolean>,
    )

    private val ackWaiters = mutableMapOf<G1Side, AckWaiter>()
    private var generationCounter: Long = 0

    private val sentLogInternal = mutableListOf<G1SentPacket>()

    /** Every packet written so far, in order. */
    val sentLog: List<G1SentPacket>
        get() = synchronized(sentLogInternal) { sentLogInternal.toList() }

    /**
     * Enqueues a command; suspends until it (and everything queued before it)
     * has been written — and ACKed, when required.
     *
     * @return true on success; false when an ACK-required command exhausted
     *         its retries.
     */
    suspend fun send(command: G1Command): Boolean = queueMutex.withLock {
        execute(command)
    }

    /**
     * Convenience for a multi-packet screen write: all packets to the left
     * lens with [DEFAULT_CHUNK_PACING_MILLIS] pacing, then the load-bearing
     * [INTER_SIDE_DELAY_MILLIS] settle, then the same packets to the right.
     *
     * Held under one queue lock so heartbeats cannot interleave mid-screen.
     */
    suspend fun sendScreen(packets: List<ByteArray>): Boolean = queueMutex.withLock {
        var allOk = true
        packets.forEachIndexed { index, packet ->
            val isLastLeft = index == packets.size - 1
            val ok = execute(
                G1Command(
                    bytes = packet,
                    sides = listOf(G1Side.LEFT),
                    // 400 ms settle after the final left packet — load-bearing.
                    postDelayMillis =
                        if (isLastLeft) INTER_SIDE_DELAY_MILLIS
                        else DEFAULT_CHUNK_PACING_MILLIS,
                )
            )
            allOk = allOk && ok
        }
        packets.forEach { packet ->
            val ok = execute(G1Command(bytes = packet, sides = listOf(G1Side.RIGHT)))
            allOk = allOk && ok
        }
        allOk
    }

    /** Feed inbound frames here so ACK waiters resolve. */
    suspend fun handleInbound(data: ByteArray, side: G1Side) {
        val event = G1StatusDecoder.decode(data)
        if (event !is G1StatusEvent.Ack) return
        stateMutex.withLock {
            val waiter = ackWaiters[side] ?: return@withLock
            if (waiter.expectedCommand != event.command) return@withLock
            ackWaiters.remove(side)
            waiter.deferred.complete(event.success)
        }
    }

    /** Drops all waiters (call on disconnect). */
    suspend fun reset() {
        stateMutex.withLock {
            ackWaiters.values.forEach { it.deferred.complete(false) }
            ackWaiters.clear()
        }
    }

    // MARK: - Internals (callers must already hold queueMutex)

    private suspend fun execute(command: G1Command): Boolean {
        return when (val policy = command.ackPolicy) {
            is G1AckPolicy.None -> {
                command.sides.forEach { side ->
                    writer.write(command.bytes, side)
                    record(command.bytes, side)
                }
                if (command.postDelayMillis > 0) delay(command.postDelayMillis)
                true
            }

            is G1AckPolicy.Required -> {
                for (attempt in 1..MAX_ATTEMPTS) {
                    var allAcked = true
                    for (side in command.sides) {
                        val waiter = registerWaiter(side, policy.command)
                        writer.write(command.bytes, side)
                        record(command.bytes, side)
                        val acked = awaitAck(side, waiter)
                        allAcked = allAcked && acked
                    }
                    if (allAcked) {
                        if (command.postDelayMillis > 0) delay(command.postDelayMillis)
                        return true
                    }
                    if (attempt < MAX_ATTEMPTS) delay(RETRY_BACKOFF_MILLIS)
                }
                false
            }
        }
    }

    private suspend fun registerWaiter(side: G1Side, expectedCommand: Byte): AckWaiter =
        stateMutex.withLock {
            // A waiter left over for this side (e.g. a prior timed-out attempt)
            // is superseded — resolve it false so nothing hangs on it.
            ackWaiters.remove(side)?.deferred?.complete(false)
            generationCounter += 1
            val waiter = AckWaiter(
                generation = generationCounter,
                expectedCommand = expectedCommand,
                deferred = CompletableDeferred(),
            )
            ackWaiters[side] = waiter
            waiter
        }

    private suspend fun awaitAck(side: G1Side, waiter: AckWaiter): Boolean =
        try {
            // The timeout is scoped to this await: when the ACK lands, the
            // timer is cancelled with it and can never clear a later waiter.
            withTimeout(ackTimeoutMillis) { waiter.deferred.await() }
        } catch (_: TimeoutCancellationException) {
            stateMutex.withLock {
                // Only clear the waiter if it is still OUR generation.
                if (ackWaiters[side]?.generation == waiter.generation) {
                    ackWaiters.remove(side)
                }
            }
            waiter.deferred.complete(false)
            false
        }

    private fun record(bytes: ByteArray, side: G1Side) {
        synchronized(sentLogInternal) { sentLogInternal.add(G1SentPacket(bytes, side)) }
    }
}
