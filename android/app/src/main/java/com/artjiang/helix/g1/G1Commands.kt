// Port of the command-encoding half of
// NativeHelix/Sources/HelixG1/G1Commands.swift.
//
// Builds outbound G1 BLE command packets. Byte layouts follow the MentraOS
// reference implementation (mobile/modules/bluetooth-sdk, sgcs/G1.swift|kt),
// which is the most complete open-source G1 driver.
//
// Pure Kotlin/JVM: no android.* imports, so every byte layout is JVM-testable.
package com.artjiang.helix.g1

import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object G1CommandEncoder {
    /** Max JSON payload per chunk for chunked-JSON commands (0x04, 0x4B). */
    const val JSON_CHUNK_SIZE = 176

    // MARK: - Fixed / small commands

    /** Init handshake sent after both characteristics are ready. Expects ACK `0x4D 0xC9`. */
    fun initHandshake(): ByteArray = byteArrayOf(0x4D, 0xFB.toByte())

    /** Keep-alive; send every 10-20 s. The counter is echoed back. */
    fun heartbeat(counter: Byte): ByteArray =
        byteArrayOf(0x25, counter, 0x00, 0x04, counter)

    /** Battery status request. Response: `[0x2C, 0x66, batt%, flags, vLo, vHi]`. */
    fun batteryPoll(): ByteArray = byteArrayOf(0x2C)

    /** Brightness 0-63 plus auto-brightness flag. */
    fun brightness(level: Int, autoBrightness: Boolean): ByteArray =
        byteArrayOf(
            0x01,
            level.coerceIn(0, 63).toByte(),
            if (autoBrightness) 0x01 else 0x00,
        )

    /** Disables silent mode (part of the init sequence). */
    fun silentModeOff(): ByteArray = byteArrayOf(0x03, 0x0A)

    /** Disables firmware wear detection (part of the init sequence). */
    fun wearDetectionOff(): ByteArray = byteArrayOf(0x27, 0x00)

    /** Head-up detection angle, 0-60 degrees. */
    fun headUpAngle(degrees: Int): ByteArray =
        byteArrayOf(0x0B, degrees.coerceIn(0, 60).toByte(), 0x01)

    /**
     * HUD position. Height 0 (bottom) - 8 (top); depth 0 (far) - 9 (near).
     * Expects ACK `0x06`.
     */
    fun displayPosition(height: Int, depth: Int, counter: Byte): ByteArray =
        byteArrayOf(
            0x26,
            0x08,
            0x00,
            counter,
            0x02,
            0x01,
            height.coerceIn(0, 8).toByte(),
            depth.coerceIn(0, 9).toByte(),
        )

    /** Glasses-side microphone stream on/off (0xF1 PCM frames follow when on). */
    fun microphone(enabled: Boolean): ByteArray =
        byteArrayOf(0x0E, if (enabled) 0x01 else 0x00)

    /** Clears the screen and exits the current firmware function. */
    fun exitAllFunctions(): ByteArray = byteArrayOf(0x18)

    /** Firmware info request. */
    fun firmwareInfoRequest(): ByteArray = byteArrayOf(0x6E, 0x74)

    /**
     * Date/time sync so the firmware dashboard shows the right clock.
     * Layout: `[0x06, 0x15, 0x00, counter, 0x01, epoch32 LE, epoch64ms LE]`
     * (0x15 = fixed length byte 21). Expects ACK `0x07/0x90/0x0C`.
     *
     * @param epochMillis wall-clock time in milliseconds since 1970.
     */
    fun dateTimeSync(epochMillis: Long, counter: Byte): ByteArray {
        val seconds = (epochMillis / 1000L).coerceIn(0L, 0xFFFF_FFFFL)
        val millis = epochMillis.coerceAtLeast(0L)
        val packet = ByteArray(17)
        packet[0] = 0x06
        packet[1] = 0x15
        packet[2] = 0x00
        packet[3] = counter
        packet[4] = 0x01
        // epoch seconds, 4 bytes little-endian
        for (i in 0 until 4) {
            packet[5 + i] = ((seconds shr (8 * i)) and 0xFF).toByte()
        }
        // epoch milliseconds, 8 bytes little-endian
        for (i in 0 until 8) {
            packet[9 + i] = ((millis shr (8 * i)) and 0xFF).toByte()
        }
        return packet
    }

    // MARK: - Chunked JSON commands

    /** One app entry in the notification whitelist. */
    data class WhitelistApp(val id: String, val name: String)

    /**
     * Notification whitelist config (chunked JSON, command 0x04).
     * Header per chunk: `[0x04, totalChunks, chunkIndex]`.
     */
    fun notificationWhitelist(
        appIdentifiers: List<WhitelistApp>,
        calendarEnabled: Boolean = true,
        callEnabled: Boolean = true,
        messageEnabled: Boolean = true,
        mailEnabled: Boolean = true,
    ): List<ByteArray> {
        // Swift uses JSONSerialization with .sortedKeys — keys are emitted in
        // ascending order at every level. JsonWriter reproduces that ordering
        // so the bytes on the wire match.
        val json = JsonWriter.obj(
            "app" to JsonWriter.obj(
                "enable" to JsonWriter.bool(true),
                "list" to JsonWriter.array(
                    appIdentifiers.map {
                        JsonWriter.obj(
                            "id" to JsonWriter.str(it.id),
                            "name" to JsonWriter.str(it.name),
                        )
                    }
                ),
            ),
            "calendar_enable" to JsonWriter.bool(calendarEnabled),
            "call_enable" to JsonWriter.bool(callEnabled),
            "ios_mail_enable" to JsonWriter.bool(mailEnabled),
            "msg_enable" to JsonWriter.bool(messageEnabled),
        )
        return chunkJson(json.toByteArray(Charsets.UTF_8)) { total, index ->
            byteArrayOf(0x04, total, index)
        }
    }

    /**
     * Phone-notification push (chunked JSON, command 0x4B).
     * Header per chunk: `[0x4B, notifyId, totalChunks, chunkIndex]`.
     *
     * @param epochMillis notification timestamp in milliseconds since 1970.
     */
    fun notification(
        messageId: Int,
        appIdentifier: String,
        displayName: String,
        title: String,
        subtitle: String = "",
        message: String,
        epochMillis: Long,
        notifyId: Byte = 0,
    ): List<ByteArray> {
        val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        val json = JsonWriter.obj(
            "ncs_notification" to JsonWriter.obj(
                "app_identifier" to JsonWriter.str(appIdentifier),
                "date" to JsonWriter.str(formatter.format(java.util.Date(epochMillis))),
                "display_name" to JsonWriter.str(displayName),
                "message" to JsonWriter.str(message),
                "msg_id" to JsonWriter.num(messageId.toLong()),
                "subtitle" to JsonWriter.str(subtitle),
                "time_s" to JsonWriter.num(epochMillis / 1000L),
                "title" to JsonWriter.str(title),
                "type" to JsonWriter.num(1),
            ),
            "type" to JsonWriter.str("Add"),
        )
        return chunkJson(json.toByteArray(Charsets.UTF_8)) { total, index ->
            byteArrayOf(0x4B, notifyId, total, index)
        }
    }

    private inline fun chunkJson(
        bytes: ByteArray,
        header: (total: Byte, index: Byte) -> ByteArray,
    ): List<ByteArray> {
        val chunks: List<ByteArray> = if (bytes.isEmpty()) {
            listOf(ByteArray(0))
        } else {
            (bytes.indices step JSON_CHUNK_SIZE).map { start ->
                bytes.copyOfRange(start, minOf(start + JSON_CHUNK_SIZE, bytes.size))
            }
        }
        val total = G1PacketEncoder.clampToUByte(chunks.size)
        return chunks.mapIndexed { index, chunk ->
            header(total, G1PacketEncoder.clampToUByte(index)) + chunk
        }
    }
}

/**
 * Minimal JSON emitter with deterministic (caller-supplied, already sorted)
 * key ordering, matching Swift's `JSONSerialization` with `.sortedKeys`.
 * kotlinx-serialization's JsonObject does not guarantee the same separator
 * style, so this keeps the byte output pinned.
 */
internal object JsonWriter {
    fun str(value: String): String = buildString {
        append('"')
        for (ch in value) {
            when (ch) {
                '"' -> append("\\\"")
                '\\' -> append("\\\\")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> if (ch < ' ') append("\\u%04x".format(ch.code)) else append(ch)
            }
        }
        append('"')
    }

    fun num(value: Long): String = value.toString()

    fun bool(value: Boolean): String = if (value) "true" else "false"

    fun array(elements: List<String>): String = elements.joinToString(",", "[", "]")

    fun obj(vararg entries: Pair<String, String>): String =
        entries.joinToString(",", "{", "}") { (key, value) -> "${str(key)}:$value" }
}
