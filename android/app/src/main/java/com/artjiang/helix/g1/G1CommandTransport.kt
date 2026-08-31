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
enum class G1Side {
    LEFT,
    RIGHT;

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

    companion object {
        /**
         * ACK-required command whose expected ACK byte is derived from the
         * command byte itself (G1 ACK frames echo it). Keeping the derivation
         * here — instead of raw literals at every call site — removes the
         * class of drift where a caller waits on the wrong byte and burns the
         * full retry budget in silence.
         */
        fun withAck(bytes: ByteArray, sides: List<G1Side> = G1Side.ALL): G1Command {
            require(bytes.isNotEmpty()) { "an ACK-required command needs a command byte" }
            return G1Command(bytes = bytes, sides = sides, ackPolicy = G1AckPolicy.Required(bytes[0]))
        }
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

/** Typed result for one lens during a whole-screen write. */
enum class G1LensDeliveryStatus {
    /** Every packet was accepted and ACKed by this lens. */
    DELIVERED,

    /** The first write was refused before any bytes left the phone. */
    ABSENT,

    /** The lens accepted bytes, then timed out, NAKed, or dropped mid-screen. */
    FAILED,

    /** This lens was not tried (empty payload or SLA-L1 left-side abort). */
    NOT_ATTEMPTED,
}

/** Which eyes actually received a successfully completed screen. */
enum class G1ScreenDeliveryCoverage { BOTH, LEFT_ONLY, RIGHT_ONLY, NONE }

/**
 * ACK-backed, per-lens result of a complete screen push.
 *
 * This value deliberately survives beyond transport diagnostics. A Boolean
 * cannot distinguish a dual-lens delivery from the supported one-lens case,
 * which made the Assistant claim "Delivered to glasses" while one eye had no
 * content. [coverage] is user-facing truth; [left]/[right] retain the precise
 * transport reason for diagnostics.
 */
data class G1ScreenDeliveryOutcome(
    val left: G1LensDeliveryStatus,
    val right: G1LensDeliveryStatus,
    val packetCount: Int,
) {
    val coverage: G1ScreenDeliveryCoverage
        get() = when {
            left == G1LensDeliveryStatus.DELIVERED &&
                right == G1LensDeliveryStatus.DELIVERED -> G1ScreenDeliveryCoverage.BOTH
            left == G1LensDeliveryStatus.DELIVERED -> G1ScreenDeliveryCoverage.LEFT_ONLY
            right == G1LensDeliveryStatus.DELIVERED -> G1ScreenDeliveryCoverage.RIGHT_ONLY
            else -> G1ScreenDeliveryCoverage.NONE
        }

    /** Same acceptance rule as the former Boolean API. */
    val isSuccessful: Boolean
        get() = coverage != G1ScreenDeliveryCoverage.NONE &&
            left != G1LensDeliveryStatus.FAILED &&
            right != G1LensDeliveryStatus.FAILED

    val isFullDelivery: Boolean
        get() = isSuccessful && coverage == G1ScreenDeliveryCoverage.BOTH

    fun diagnostic(): String =
        "left=$left right=$right ($packetCount pkts)"

    companion object {
        fun deliveredToBoth(packetCount: Int = 1) = G1ScreenDeliveryOutcome(
            G1LensDeliveryStatus.DELIVERED,
            G1LensDeliveryStatus.DELIVERED,
            packetCount,
        )

        fun deliveredToLeft(packetCount: Int = 1) = G1ScreenDeliveryOutcome(
            G1LensDeliveryStatus.DELIVERED,
            G1LensDeliveryStatus.ABSENT,
            packetCount,
        )

        fun deliveredToRight(packetCount: Int = 1) = G1ScreenDeliveryOutcome(
            G1LensDeliveryStatus.ABSENT,
            G1LensDeliveryStatus.DELIVERED,
            packetCount,
        )

        fun failed(packetCount: Int = 1) = G1ScreenDeliveryOutcome(
            G1LensDeliveryStatus.FAILED,
            G1LensDeliveryStatus.NOT_ATTEMPTED,
            packetCount,
        )
    }
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
    /** Per-packet ACK budget for [sendScreen]; see [SCREEN_ACK_TIMEOUT_MILLIS]. */
    private val screenAckTimeoutMillis: Long = SCREEN_ACK_TIMEOUT_MILLIS,
) {
    companion object {
        const val DEFAULT_ACK_TIMEOUT_MILLIS: Long = 5_000
        const val MAX_ATTEMPTS = 3
        const val RETRY_BACKOFF_MILLIS: Long = 100

        /** Default inter-chunk pacing for a multi-packet screen write. */
        const val DEFAULT_CHUNK_PACING_MILLIS: Long = 8

        /** Diagnostics ring-buffer size for [sentLog]. */
        const val SENT_LOG_CAPACITY = 256

        /**
         * LOAD-BEARING: the 400 ms settle between finishing the left lens and
         * starting the right one. Removing or shortening this reliably breaks
         * streaming HUD updates on real hardware (the right lens drops or
         * garbles the page). Documented in
         * memory/reference_evenai_400ms_delay.md as
         * `Proto.evenAIInterSideDelay`. DO NOT REMOVE.
         *
         * ## Why it survives ACK gating (SLA-L1)
         * The vendor app has no inter-side sleep at all: `proto.dart:55-71`
         * orders the sides by *acknowledgment*, not by wall clock — the whole
         * left list must ACK before the first right packet is written. The
         * 400 ms here was almost certainly a stand-in for exactly that missing
         * back-pressure: with fire-and-forget writes, a fixed sleep was the
         * only way to stop the phone from cramming the right lens while the
         * left was still draining.
         *
         * Now that [sendScreen] is genuinely ACK-gated, this delay is
         * *plausibly* redundant. It is deliberately KEPT because the constant
         * is hardware-verified and the replacement is not: nobody has put the
         * ACK-gated path in front of real glasses yet. Removing it is a
         * follow-up to run on hardware — send a multi-page streaming answer
         * with the delay set to 0 and confirm the right lens neither drops nor
         * garbles a page. Until that test passes, DO NOT REMOVE.
         */
        const val INTER_SIDE_DELAY_MILLIS: Long = 400

        /**
         * Per-packet ACK timeout for a screen write. SLA-L2: the vendor's
         * `sendEvenAIData` passes 2000 ms for `0x4E` text packets
         * (`proto.dart:64,71`), against a 350 ms default for everything else
         * (`ble_manager.dart:391`). Text gets the longer budget because a
         * rendering lens can be slow to turn the packet around.
         */
        const val SCREEN_ACK_TIMEOUT_MILLIS: Long = 2_000
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

    /**
     * The generation of the most recent waiter registered for each side.
     *
     * Every packet of a screen carries the SAME command byte (0x4E), so
     * matching an inbound ACK on `side + expectedCommand` alone is not enough:
     * a late ACK belonging to a packet that already timed out would satisfy the
     * NEXT packet's waiter and falsely report it delivered. Gating on the
     * per-side latest generation makes a straggler inert.
     *
     * This is deliberately PER-SIDE rather than the global [generationCounter]:
     * the counter also advances when the other lens registers a waiter, which
     * would invalidate a perfectly live waiter on this side.
     */
    private val latestGeneration = mutableMapOf<G1Side, Long>()

    private var generationCounter: Long = 0

    private val sentLogInternal = ArrayDeque<G1SentPacket>()

    /**
     * Per-lens result of the most recent [sendScreen], for diagnostics.
     *
     * A screen that reaches one lens but not the other is invisible from the
     * app side — `sendScreen` returns true whenever EITHER lens took it, which
     * is deliberate (single-lens links are supported) but means a persistently
     * failing right lens looks identical to success. Surfacing the per-side
     * outcome is what turns "the right eye is wrong" into a readable fact.
     */
    @Volatile
    var lastScreenDeliveryOutcome: G1ScreenDeliveryOutcome? = null
        private set

    /** Human-readable compatibility surface for the Device diagnostics card. */
    val lastScreenOutcome: String
        get() = lastScreenDeliveryOutcome?.diagnostic() ?: "none"

    /**
     * The most recent packets written (up to [SENT_LOG_CAPACITY]), in order.
     * Bounded so a long-lived session cannot grow memory per packet.
     */
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
     * Writes one multi-packet screen: every packet to the left lens, then the
     * same packets to the right. Held under one queue lock so heartbeats cannot
     * interleave mid-screen.
     *
     * ## SLA-L2 — every text packet is individually ACK-gated (MUST)
     * `ble_manager.dart:391-399` awaits a reply per packet and aborts the list
     * on the first timeout or non-`0xC9`/`0xCB` status. Text packets MUST NOT
     * be fire-and-forget, which is what they were here: a lens that silently
     * dropped half a page was indistinguishable from a clean write, which is
     * precisely why every HUD failure mode looked identical from the phone.
     * Each packet now goes out as [G1Command.withAck] with the
     * [SCREEN_ACK_TIMEOUT_MILLIS] budget the vendor uses for `0x4E`.
     *
     * ## SLA-L1 — left fully succeeds before right begins (MUST)
     * `proto.dart:55-71` returns false without ever writing to the right lens
     * when the left list fails. We now abort the same way, and — like the
     * vendor — stop at the FIRST failed packet rather than pushing the rest of
     * a page the lens has already lost track of.
     *
     * ## Single-lens reconciliation (deliberate divergence)
     * The vendor assumes both lenses are present. Helix supports a one-lens
     * link as a first-class state: `HelixBridge.isGlassesConnected` is
     * `left READY || right READY` and G1BluetoothManager reports
     * "Connected (left lens)". ANDing both sides fails the whole screen on the
     * absent lens's `false`; G1HudSession aborts its lifecycle on a failed
     * push, so DISPLAY_COMPLETE is never scheduled — the HUD stays lit forever
     * and "Send to glasses" looks like a no-op. That must not regress.
     *
     * The two are reconciled by distinguishing *absent* from *broken*:
     *  - A lens whose very first write is REJECTED BY THE STACK never had a
     *    link — it is disconnected, not failing. We skip the rest of that
     *    lens's packets and let the other lens carry the screen.
     *  - A lens that ACCEPTED the write and then failed (ACK timeout, NAK,
     *    a mid-page write rejection) is a genuine, in-flight failure: it is
     *    holding a half-drawn page. Per SLA-L1 that aborts the screen — for
     *    the left lens the right is never written at all.
     *
     * So the screen succeeds when at least one lens took ALL of it and no
     * present lens failed part-way. Two absent lenses still fail.
     */
    suspend fun sendScreen(packets: List<ByteArray>): Boolean =
        sendScreenDetailed(packets).isSuccessful

    /**
     * Typed screen API used by the HUD/feed path. Unlike [sendScreen], this
     * retains which lens acknowledged the content all the way to the UI.
     */
    suspend fun sendScreenDetailed(packets: List<ByteArray>): G1ScreenDeliveryOutcome =
        queueMutex.withLock {
            if (packets.isEmpty()) {
                return@withLock recordScreenOutcome(
                    G1ScreenDeliveryOutcome(
                        G1LensDeliveryStatus.NOT_ATTEMPTED,
                        G1LensDeliveryStatus.NOT_ATTEMPTED,
                        packetCount = 0,
                    ),
                )
            }

            val left = sendScreenToSide(packets, G1Side.LEFT, isLastSide = false)
            // SLA-L1: a left lens that was present and failed aborts the screen;
            // the right lens is never written. (The vendor aborts unconditionally;
            // we exempt the absent-lens case above.)
            if (left == SideOutcome.FAILED) {
                return@withLock recordScreenOutcome(
                    G1ScreenDeliveryOutcome(
                        left = left.publicStatus,
                        right = G1LensDeliveryStatus.NOT_ATTEMPTED,
                        packetCount = packets.size,
                    ),
                )
            }

            val right = sendScreenToSide(packets, G1Side.RIGHT, isLastSide = true)
            recordScreenOutcome(
                G1ScreenDeliveryOutcome(
                    left = left.publicStatus,
                    right = right.publicStatus,
                    packetCount = packets.size,
                ),
            )
        }

    /** How one lens fared on a screen write. */
    private enum class SideOutcome {
        /** Every packet was written and ACKed. */
        DELIVERED,

        /** No link at all — the first write was refused before any bytes went out. */
        ABSENT,

        /** The lens was present and failed mid-screen (ACK timeout, NAK, drop). */
        FAILED,

        ;

        val publicStatus: G1LensDeliveryStatus
            get() = when (this) {
                DELIVERED -> G1LensDeliveryStatus.DELIVERED
                ABSENT -> G1LensDeliveryStatus.ABSENT
                FAILED -> G1LensDeliveryStatus.FAILED
            }
    }

    private fun recordScreenOutcome(outcome: G1ScreenDeliveryOutcome): G1ScreenDeliveryOutcome {
        lastScreenDeliveryOutcome = outcome
        return outcome
    }

    private suspend fun sendScreenToSide(
        packets: List<ByteArray>,
        side: G1Side,
        isLastSide: Boolean,
    ): SideOutcome {
        packets.forEachIndexed { index, packet ->
            val isLastPacket = index == packets.size - 1
            val result = executeDetailed(
                G1Command.withAck(bytes = packet, sides = listOf(side)).copy(
                    // The load-bearing 400 ms settle goes after the final left
                    // packet only; no trailing pause once the screen is done.
                    postDelayMillis = when {
                        !isLastPacket -> DEFAULT_CHUNK_PACING_MILLIS
                        isLastSide -> 0
                        else -> INTER_SIDE_DELAY_MILLIS
                    },
                ),
                ackTimeoutOverrideMillis = screenAckTimeoutMillis,
            )
            when {
                result == ExecuteResult.SUCCESS -> Unit
                // First packet refused by the stack => this lens never had a
                // link; treat it as absent and let the other lens carry the
                // screen. Anything else means the lens WAS talking to us and
                // then broke, which is a real failure.
                index == 0 && result == ExecuteResult.WRITE_REJECTED ->
                    return SideOutcome.ABSENT

                else -> return SideOutcome.FAILED
            }
        }
        return SideOutcome.DELIVERED
    }

    /** Feed inbound frames here so ACK waiters resolve. */
    suspend fun handleInbound(data: ByteArray, side: G1Side) =
        handleDecoded(G1StatusDecoder.decode(data), side)

    /** Variant for callers that already decoded the frame (avoids a second decode). */
    suspend fun handleDecoded(event: G1StatusEvent?, side: G1Side) {
        if (event !is G1StatusEvent.Ack) return
        stateMutex.withLock {
            val waiter = ackWaiters[side] ?: return@withLock
            if (waiter.expectedCommand != event.command) return@withLock
            // Defence in depth against the straggler-ACK race: every packet of a
            // screen carries the same command byte (0x4E), so a late ACK for an
            // abandoned packet is byte-identical to the one its successor awaits.
            //
            // NOTE: with the current single-waiter-per-side map this condition is
            // not reachable — `awaitAck`'s timeout path and `registerWaiter` both
            // remove a superseded waiter, so an inbound frame can only ever find
            // the live one. It is kept as a cheap invariant: if the map is ever
            // widened (a queue of in-flight packets per side, pipelined writes),
            // this is the line that stops a straggler completing the wrong waiter.
            if (waiter.generation != latestGeneration[side]) return@withLock
            ackWaiters.remove(side)
            waiter.deferred.complete(event.success)
        }
    }

    /** Drops all waiters (call on disconnect). */
    suspend fun reset() {
        stateMutex.withLock {
            ackWaiters.values.forEach { it.deferred.complete(false) }
            ackWaiters.clear()
            // Generations only ever increase, so a stale entry could not match
            // a future waiter anyway — but clearing keeps the map from growing
            // an entry per side that outlives the link it belonged to.
            latestGeneration.clear()
        }
    }

    // MARK: - Internals (callers must already hold queueMutex)

    /**
     * Why a command finished the way it did. [sendScreen] needs to tell an
     * absent lens (the stack refused the bytes outright) from a present lens
     * that failed to acknowledge — the two mean very different things for
     * single-lens support. Ordinary [send] callers only care about success.
     */
    private enum class ExecuteResult {
        SUCCESS,

        /** No bytes ever left the phone: the BLE stack refused every attempt. */
        WRITE_REJECTED,

        /** Bytes went out, but the lens never acknowledged them (or NAKed). */
        ACK_FAILED,
    }

    private suspend fun execute(command: G1Command): Boolean =
        executeDetailed(command) == ExecuteResult.SUCCESS

    private suspend fun executeDetailed(
        command: G1Command,
        ackTimeoutOverrideMillis: Long? = null,
    ): ExecuteResult {
        return when (val policy = command.ackPolicy) {
            is G1AckPolicy.None -> {
                var allWrote = true
                command.sides.forEach { side ->
                    val wrote = writer.write(command.bytes, side)
                    record(command.bytes, side)
                    allWrote = allWrote && wrote
                }
                if (command.postDelayMillis > 0) delay(command.postDelayMillis)
                if (allWrote) ExecuteResult.SUCCESS else ExecuteResult.WRITE_REJECTED
            }

            is G1AckPolicy.Required -> {
                val timeout = ackTimeoutOverrideMillis ?: ackTimeoutMillis
                // Distinguishes "the stack never took the bytes on any attempt"
                // from "the bytes went out but were not acknowledged".
                var anyWriteAccepted = false
                for (attempt in 1..MAX_ATTEMPTS) {
                    var allAcked = true
                    for (side in command.sides) {
                        val waiter = registerWaiter(side, policy.command)
                        val wrote = writer.write(command.bytes, side)
                        record(command.bytes, side)
                        val acked = if (wrote) {
                            anyWriteAccepted = true
                            awaitAck(side, waiter, timeout)
                        } else {
                            // The stack rejected the write (lens disconnected,
                            // link torn down): no bytes went out, so waiting the
                            // full ACK timeout would just stall the queue.
                            clearWaiter(side, waiter)
                            false
                        }
                        allAcked = allAcked && acked
                    }
                    if (allAcked) {
                        if (command.postDelayMillis > 0) delay(command.postDelayMillis)
                        return ExecuteResult.SUCCESS
                    }
                    if (attempt < MAX_ATTEMPTS) delay(RETRY_BACKOFF_MILLIS)
                }
                if (anyWriteAccepted) ExecuteResult.ACK_FAILED else ExecuteResult.WRITE_REJECTED
            }
        }
    }

    private suspend fun clearWaiter(side: G1Side, waiter: AckWaiter) {
        stateMutex.withLock {
            if (ackWaiters[side]?.generation == waiter.generation) {
                ackWaiters.remove(side)
            }
        }
        waiter.deferred.complete(false)
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
            latestGeneration[side] = waiter.generation
            waiter
        }

    private suspend fun awaitAck(
        side: G1Side,
        waiter: AckWaiter,
        timeoutMillis: Long = ackTimeoutMillis,
    ): Boolean =
        try {
            // The timeout is scoped to this await: when the ACK lands, the
            // timer is cancelled with it and can never clear a later waiter.
            withTimeout(timeoutMillis) { waiter.deferred.await() }
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
        synchronized(sentLogInternal) {
            if (sentLogInternal.size >= SENT_LOG_CAPACITY) sentLogInternal.removeFirst()
            sentLogInternal.add(G1SentPacket(bytes, side))
        }
    }
}
