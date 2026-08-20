// Port of the status-decoding half of
// NativeHelix/Sources/HelixG1/G1Commands.swift.
package com.artjiang.helix.g1

enum class G1CaseState { REMOVED, OPEN, CLOSED }

/**
 * Typed inbound frames from the glasses that are not touchpad presses.
 * Touchpad notifyIndex routing stays in [G1TouchpadRouter].
 */
sealed interface G1StatusEvent {
    data object HeadUp : G1StatusEvent
    data object HeadDown : G1StatusEvent
    data class CaseState(val state: G1CaseState) : G1StatusEvent
    data class CaseCharging(val isCharging: Boolean) : G1StatusEvent
    data class CaseBatteryPercent(val percent: Int) : G1StatusEvent
    data class Battery(val percent: Int, val isCharging: Boolean) : G1StatusEvent
    data class Ack(val command: Byte, val success: Boolean) : G1StatusEvent
    data class FirmwareInfo(val text: String) : G1StatusEvent
}

/**
 * Inbound touchpad frame. The 0xF5 family carries both status sub-codes
 * (head up/down, case) and touchpad notify indices; [G1StatusDecoder.decode]
 * handles the former, [decodeTouchpad] extracts the latter so the caller can
 * feed it to [G1TouchpadRouter].
 */
data class G1TouchpadFrame(val notifyIndex: Int, val side: G1TouchpadSide)

object G1StatusDecoder {
    const val ACK_SUCCESS: Byte = 0xC9.toByte()
    const val ACK_CONTINUE: Byte = 0xCB.toByte()

    /** 0xF5 sub-codes that are touchpad notify indices rather than status events. */
    private val TOUCHPAD_INDICES = setOf(0, 1, 23, 24)

    /**
     * Decodes one inbound frame into a status event, or null when the frame is
     * not a status frame (mic data 0xF1, touchpad presses, etc.).
     */
    fun decode(data: ByteArray): G1StatusEvent? {
        if (data.isEmpty()) return null
        return when (val command = data[0]) {
            0xF5.toByte() -> decodeF5(data)

            0x2C.toByte() -> {
                if (data.size < 4 || data[1] != 0x66.toByte()) return null
                val percent = data[2].toInt() and 0xFF
                val charging = (data[3].toInt() and 0x01) == 0x01
                G1StatusEvent.Battery(percent = minOf(100, percent), isCharging = charging)
            }

            0x4D.toByte(), 0x26.toByte(), 0x06.toByte(), 0x0B.toByte(),
            0x01.toByte(), 0x0E.toByte(), 0x04.toByte(), 0x03.toByte(),
            0x27.toByte() -> {
                if (data.size < 2) return null
                val status = data[1]
                if (status == ACK_SUCCESS || status == ACK_CONTINUE) {
                    return G1StatusEvent.Ack(command = command, success = true)
                }
                // Datetime/dashboard replies use their own success codes.
                if (command == 0x06.toByte() &&
                    status in listOf<Byte>(0x07, 0x90.toByte(), 0x0C)
                ) {
                    return G1StatusEvent.Ack(command = command, success = true)
                }
                G1StatusEvent.Ack(command = command, success = false)
            }

            0x6E.toByte() -> {
                val body = data.drop(1).takeWhile { it != 0.toByte() }.toByteArray()
                G1StatusEvent.FirmwareInfo(String(body, Charsets.UTF_8))
            }

            else -> null
        }
    }

    private fun decodeF5(data: ByteArray): G1StatusEvent? {
        if (data.size < 2) return null
        return when (data[1]) {
            0x02.toByte() -> G1StatusEvent.HeadUp
            0x03.toByte() -> G1StatusEvent.HeadDown
            0x06.toByte(), 0x07.toByte() -> G1StatusEvent.CaseState(G1CaseState.REMOVED)
            0x08.toByte() -> G1StatusEvent.CaseState(G1CaseState.OPEN)
            0x0B.toByte() -> G1StatusEvent.CaseState(G1CaseState.CLOSED)
            0x0E.toByte() -> G1StatusEvent.CaseCharging(data.size > 2 && data[2] == 0x01.toByte())
            0x0F.toByte() -> {
                if (data.size <= 2) return null
                G1StatusEvent.CaseBatteryPercent(minOf(100, data[2].toInt() and 0xFF))
            }
            else -> null
        }
    }

    /**
     * Extracts a touchpad frame from an inbound 0xF5 packet, or null when the
     * sub-code is a status event (head up/down, case) rather than a press.
     *
     * The Swift shell decodes touchpad presses in BluetoothManager and feeds
     * the notifyIndex straight into the router; this gives the Android BLE
     * layer the same split without duplicating the 0xF5 dispatch table.
     *
     * Note: indices 2 (headUp) and 3 (headDown) are intentionally NOT returned
     * here — [decode] already surfaces them as [G1StatusEvent], matching the
     * Swift behavior where the router's cases 2/3 are reachable only when the
     * shell forwards a head gesture as a touchpad index.
     */
    fun decodeTouchpad(data: ByteArray, side: G1TouchpadSide): G1TouchpadFrame? {
        if (data.size < 2 || data[0] != 0xF5.toByte()) return null
        val index = data[1].toInt() and 0xFF
        if (index !in TOUCHPAD_INDICES) return null
        return G1TouchpadFrame(notifyIndex = index, side = side)
    }
}
