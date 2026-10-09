// Even R1 ring gesture frames (Conversate Plan B). The R1 protocol is not
// published; the formats below come from community reverse-engineering
// (documented in docs/superpowers/plans/2026-10-05-conversate-plan-b-r1.md).
// This decoder is written from those formats only. Anything unrecognised is
// ignored rather than guessed, since ring firmware updates may change bytes.
package com.artjiang.helix.ring

enum class R1Gesture { TAP, DOUBLE_TAP, HOLD, HOLD_RELEASE, SWIPE_FORWARD, SWIPE_BACK }

/** A device the phone knows about; [bonded] = paired at OS level (via the Even app). */
data class RingCandidate(val name: String?, val bonded: Boolean)

object R1Frame {
    private const val SHORT_HEADER = 0xFF
    private val LONG_HEADER = intArrayOf(0x00, 0x09, 0x61, 0x00)

    fun decode(raw: ByteArray?): R1Gesture? = when (raw?.size) {
        3 -> decodeShort(raw)
        11 -> decodeLong(raw)
        else -> null
    }

    /**
     * Security: only a ring already bonded to this phone is eligible. Anyone can
     * advertise an `EVEN R1_` name, and an unbonded impostor could inject
     * gestures (e.g. end a session), so advertised names alone are never trusted.
     */
    fun pickRing(candidates: List<RingCandidate>): RingCandidate? =
        candidates.firstOrNull { it.bonded && isRingName(it.name) }

    /**
     * Command-session traffic (another app such as the Even app querying the
     * ring): `00 <4-byte id> 64 01 64 <seq> 00 <dir> 00 <cmd> <len> 00 …`.
     * Observed on device 2026-10-08 (firmware 2.3.0.0005). Never a gesture.
     */
    fun isCommandResponse(raw: ByteArray?): Boolean =
        raw != null && raw.size >= 15 && u8(raw[0]) == 0x00 &&
            u8(raw[5]) == 0x64 && u8(raw[6]) == 0x01 && u8(raw[7]) == 0x64

    /** `EVEN R1_<last 3 MAC bytes>` — the ring's advertised name. */
    fun isRingName(name: String?): Boolean = name?.startsWith("EVEN R1_") == true

    private fun decodeShort(raw: ByteArray): R1Gesture? {
        if (u8(raw[0]) != SHORT_HEADER) return null
        val type = u8(raw[1])
        val param = u8(raw[2])
        return when {
            type == 0x04 && param == 0x01 -> R1Gesture.TAP
            type == 0x04 && param == 0x02 -> R1Gesture.DOUBLE_TAP
            type == 0x03 && param == 0x20 -> R1Gesture.HOLD
            type == 0x05 -> if (param <= 0x01) R1Gesture.SWIPE_FORWARD else R1Gesture.SWIPE_BACK
            else -> null
        }
    }

    private fun decodeLong(raw: ByteArray): R1Gesture? {
        if (LONG_HEADER.indices.any { u8(raw[it]) != LONG_HEADER[it] }) return null
        return when (u8(raw[4])) {
            0x00 -> R1Gesture.HOLD
            0x01 -> R1Gesture.TAP
            0x02 -> R1Gesture.DOUBLE_TAP
            0x04 -> R1Gesture.SWIPE_BACK
            0x05 -> R1Gesture.SWIPE_FORWARD
            0x08 -> R1Gesture.HOLD_RELEASE
            else -> null
        }
    }

    private fun u8(b: Byte) = b.toInt() and 0xFF
}

/**
 * The ring can report one physical gesture on both notify characteristics
 * (short and long frame). Identical gestures within [windowMillis] count once.
 */
class R1GestureDeduper(private val clock: () -> Long, private val windowMillis: Long = 150) {
    private var last: R1Gesture? = null
    private var lastAt = Long.MIN_VALUE / 2

    fun accept(gesture: R1Gesture): Boolean {
        val now = clock()
        if (gesture == last && now - lastAt < windowMillis) return false
        last = gesture
        lastAt = now
        return true
    }
}
