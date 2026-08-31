// Port of the command-encoding half of
// NativeHelix/Sources/HelixG1/G1Commands.swift.
//
// Builds outbound G1 BLE command packets. Byte layouts follow the MentraOS
// reference implementation (mobile/modules/bluetooth-sdk, sgcs/G1.swift|kt),
// which is the most complete open-source G1 driver.
//
// Pure Kotlin/JVM: no android.* imports, so every byte layout is JVM-testable.
package com.artjiang.helix.g1

object G1CommandEncoder {
    /**
     * Max JSON payload per notification chunk (0x4B).
     *
     * Official EvenDemoApp `Proto._getNotifyPackList` slices the UTF-8 JSON at
     * 176 bytes behind a 4-byte header (`[0x4B, msgId, maxSeq, seq]`).
     */
    const val JSON_CHUNK_SIZE = 176

    /**
     * Max JSON payload per whitelist chunk (0x04).
     *
     * Official `Proto.sendNewAppWhiteListJson` calls `_getPackList(0x04, data,
     * count: 180)`, and `_getPackList` slices at `count - 3` (the 3-byte header
     * `[0x04, maxSeq, seq]`) — i.e. 177 payload bytes, not 176.
     */
    const val WHITELIST_CHUNK_SIZE = 177

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
     * HUD height/depth — `[0x26, 0x08, 0x00, seq, 0x02, preview, height, depth]`.
     *
     * TWO-PHASE, and the second phase is NOT optional. Per the protocol
     * reference (`AGiXT/mobile`, "Even Realities G1 BLE Protocol.txt"):
     *
     * > "Control the display's height and depth. Must be called twice, first
     * > with the preview bit set to 1, and then a few seconds later with the
     * > bit set 0."
     *
     * [preview] `true` shows the placement preview on the lens; `false` commits
     * it and dismisses the preview. Sending only the preview leaves the glasses
     * showing it indefinitely — observed on hardware 2026-08-30 as "the
     * dashboard appears and stays on", which is what an earlier revision did by
     * hard-coding this byte to 1 and never following up. See SLA-L3b.
     *
     * @param height 0 (bottom) - 8 (top)
     * @param depth  1 (near) - 9 (far)
     */
    fun displayPosition(
        height: Int,
        depth: Int,
        counter: Byte,
        preview: Boolean = false,
    ): ByteArray =
        byteArrayOf(
            0x26,
            0x08,
            0x00,
            counter,
            0x02,
            if (preview) 0x01 else 0x00,
            height.coerceIn(0, 8).toByte(),
            // Depth is 1-based in the reference (0x01-0x09), unlike height.
            depth.coerceIn(1, 9).toByte(),
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
     * Header per chunk: `[0x04, totalChunks, chunkIndex]`, payload ≤
     * [WHITELIST_CHUNK_SIZE] bytes of UTF-8 JSON.
     *
     * Key order and the four `*_enable` defaults are byte-for-byte the official
     * `NotifyWhitelistModel.toMap()` (EvenDemoApp
     * `lib/views/features/notification/notify_model.dart`), which Dart's
     * `jsonEncode` emits in insertion order:
     * `{"calendar_enable":…,"call_enable":…,"msg_enable":…,"ios_mail_enable":…,
     *   "app":{"list":[{"id":…,"name":…}],"enable":true}}`
     *
     * The four native categories default to **false** there: this app only
     * mirrors from its own whitelist, and leaving the firmware's own
     * call/calendar/SMS/mail channels on would double-post.
     *
     * Sent to the LEFT lens only (see `G1NotificationSender`).
     */
    fun notificationWhitelist(
        appIdentifiers: List<WhitelistApp>,
        calendarEnabled: Boolean = false,
        callEnabled: Boolean = false,
        messageEnabled: Boolean = false,
        mailEnabled: Boolean = false,
    ): List<ByteArray> {
        val json = JsonWriter.obj(
            "calendar_enable" to JsonWriter.bool(calendarEnabled),
            "call_enable" to JsonWriter.bool(callEnabled),
            "msg_enable" to JsonWriter.bool(messageEnabled),
            "ios_mail_enable" to JsonWriter.bool(mailEnabled),
            "app" to JsonWriter.obj(
                "list" to JsonWriter.array(
                    appIdentifiers.map {
                        JsonWriter.obj(
                            "id" to JsonWriter.str(it.id),
                            "name" to JsonWriter.str(it.name),
                        )
                    }
                ),
                "enable" to JsonWriter.bool(true),
            ),
        )
        return chunkJson(json.toByteArray(Charsets.UTF_8), WHITELIST_CHUNK_SIZE) { total, index ->
            byteArrayOf(0x04, total, index)
        }
    }

    /**
     * Phone-notification push (chunked JSON, command 0x4B).
     * Header per chunk: `[0x4B, msgId, totalChunks, chunkIndex]`, payload ≤
     * [JSON_CHUNK_SIZE] bytes of UTF-8 JSON.
     *
     * The body is exactly the official `NotifyModel.toMap()` wrapped in
     * `ncs_notification` (EvenDemoApp `Proto.sendNotify`), in Dart insertion
     * order:
     * `{"ncs_notification":{"msg_id":…,"app_identifier":…,"title":…,
     *   "subtitle":…,"message":…,"time_s":…,"display_name":…}}`
     *
     * [messageId] is both the JSON `msg_id` and the header's second byte — the
     * reference passes one `notifyId` to both — so it must stay in 0..255.
     * Sent to the LEFT lens only (see `G1NotificationSender`).
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
    ): List<ByteArray> {
        val id = messageId and 0xFF
        val json = JsonWriter.obj(
            "ncs_notification" to JsonWriter.obj(
                "msg_id" to JsonWriter.num(id.toLong()),
                "app_identifier" to JsonWriter.str(appIdentifier),
                "title" to JsonWriter.str(title),
                "subtitle" to JsonWriter.str(subtitle),
                "message" to JsonWriter.str(message),
                "time_s" to JsonWriter.num(epochMillis / 1000L),
                "display_name" to JsonWriter.str(displayName),
            ),
        )
        return chunkJson(json.toByteArray(Charsets.UTF_8), JSON_CHUNK_SIZE) { total, index ->
            byteArrayOf(0x4B, id.toByte(), total, index)
        }
    }

    private inline fun chunkJson(
        bytes: ByteArray,
        chunkSize: Int,
        header: (total: Byte, index: Byte) -> ByteArray,
    ): List<ByteArray> {
        val chunks = G1PacketEncoder.chunk(bytes, chunkSize)
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
