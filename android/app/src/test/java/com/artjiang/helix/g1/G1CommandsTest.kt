// Port of NativeHelix/Tests/HelixConversationTests/G1CommandsTests.swift plus
// the G1 assertions from NativeConversationTests.swift. Byte-level golden
// vectors: these must stay identical to the Swift encoders.
package com.artjiang.helix.g1

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class G1CommandsTest {

    private fun bytes(vararg values: Int): ByteArray =
        ByteArray(values.size) { values[it].toByte() }

    private fun assertBytes(expected: ByteArray, actual: ByteArray) {
        assertEquals(expected.toList().map { it.toInt() and 0xFF },
            actual.toList().map { it.toInt() and 0xFF })
    }

    // MARK: - Encoder byte layouts

    @Test
    fun coreCommandByteLayouts() {
        assertBytes(bytes(0x4D, 0xFB), G1CommandEncoder.initHandshake())
        assertBytes(bytes(0x25, 7, 0x00, 0x04, 7), G1CommandEncoder.heartbeat(7))
        assertBytes(bytes(0x2C), G1CommandEncoder.batteryPoll())
        assertBytes(bytes(0x03, 0x0A), G1CommandEncoder.silentModeOff())
        assertBytes(bytes(0x27, 0x00), G1CommandEncoder.wearDetectionOff())
        assertBytes(bytes(0x18), G1CommandEncoder.exitAllFunctions())
        assertBytes(bytes(0x6E, 0x74), G1CommandEncoder.firmwareInfoRequest())
        assertBytes(bytes(0x0E, 0x01), G1CommandEncoder.microphone(enabled = true))
        assertBytes(bytes(0x0E, 0x00), G1CommandEncoder.microphone(enabled = false))
    }

    @Test
    fun brightnessClampsRange() {
        assertBytes(bytes(0x01, 30, 0x01), G1CommandEncoder.brightness(30, true))
        assertBytes(bytes(0x01, 63, 0x00), G1CommandEncoder.brightness(99, false))
        assertBytes(bytes(0x01, 0, 0x00), G1CommandEncoder.brightness(-5, false))
    }

    @Test
    fun headUpAngleClampsRange() {
        assertBytes(bytes(0x0B, 30, 0x01), G1CommandEncoder.headUpAngle(30))
        assertBytes(bytes(0x0B, 60, 0x01), G1CommandEncoder.headUpAngle(75))
        assertBytes(bytes(0x0B, 0, 0x01), G1CommandEncoder.headUpAngle(-1))
    }

    @Test
    fun displayPositionLayoutAndClamping() {
        assertBytes(
            bytes(0x26, 0x08, 0x00, 9, 0x02, 0x01, 4, 5),
            G1CommandEncoder.displayPosition(height = 4, depth = 5, counter = 9)
        )
        assertBytes(
            bytes(0x26, 0x08, 0x00, 0, 0x02, 0x01, 8, 9),
            G1CommandEncoder.displayPosition(height = 20, depth = 20, counter = 0)
        )
    }

    @Test
    fun dateTimeSyncLayout() {
        // Swift golden: Date(timeIntervalSince1970: 1_000_000), counter 3.
        val packet = G1CommandEncoder.dateTimeSync(epochMillis = 1_000_000L * 1000L, counter = 3)

        assertEquals(17, packet.size)
        assertBytes(bytes(0x06, 0x15, 0x00, 3, 0x01), packet.copyOfRange(0, 5))

        var seconds = 0L
        for (i in 0 until 4) {
            seconds = seconds or ((packet[5 + i].toLong() and 0xFF) shl (8 * i))
        }
        assertEquals(1_000_000L, seconds)

        var millis = 0L
        for (i in 0 until 8) {
            millis = millis or ((packet[9 + i].toLong() and 0xFF) shl (8 * i))
        }
        assertEquals(1_000_000_000L, millis)
    }

    // MARK: - Chunked JSON commands

    @Test
    fun notificationChunksCarryHeaderAndReassemble() {
        val longMessage = "insight ".repeat(60)
        val chunks = G1CommandEncoder.notification(
            messageId = 12,
            appIdentifier = "com.artjiang.helix",
            displayName = "Helix",
            title = "Answer ready",
            message = longMessage,
            epochMillis = 1_700_000_000L * 1000L,
        )

        assertTrue(chunks.size > 1)
        val total = chunks[0][2].toInt() and 0xFF
        assertEquals(chunks.size, total)
        chunks.forEachIndexed { index, chunk ->
            assertEquals(0x4B, chunk[0].toInt() and 0xFF)
            assertEquals(0x00, chunk[1].toInt() and 0xFF)
            assertEquals(index, chunk[3].toInt() and 0xFF)
            assertTrue(chunk.size - 4 <= G1CommandEncoder.JSON_CHUNK_SIZE)
        }

        val json = String(
            chunks.fold(ByteArray(0)) { acc, c -> acc + c.copyOfRange(4, c.size) },
            Charsets.UTF_8
        )
        assertTrue(json.contains("\"title\":\"Answer ready\""))
        assertTrue(json.contains("\"app_identifier\":\"com.artjiang.helix\""))
        assertTrue(json.contains("\"type\":\"Add\""))
        assertTrue(json.contains("\"display_name\":\"Helix\""))
        assertTrue(json.contains("\"msg_id\":12"))
        assertTrue(json.contains("\"time_s\":1700000000"))
        // Sorted keys, matching Swift JSONSerialization .sortedKeys.
        assertTrue(json.startsWith("{\"ncs_notification\":{\"app_identifier\":"))
    }

    @Test
    fun whitelistChunksReassembleToValidJson() {
        val chunks = G1CommandEncoder.notificationWhitelist(
            listOf(G1CommandEncoder.WhitelistApp(id = "com.artjiang.helix", name = "Helix"))
        )

        chunks.forEach { assertEquals(0x04, it[0].toInt() and 0xFF) }
        val json = String(
            chunks.fold(ByteArray(0)) { acc, c -> acc + c.copyOfRange(3, c.size) },
            Charsets.UTF_8
        )
        // Exact golden output of Swift JSONSerialization with .sortedKeys.
        assertEquals(
            "{\"app\":{\"enable\":true,\"list\":[{\"id\":\"com.artjiang.helix\",\"name\":\"Helix\"}]}," +
                "\"calendar_enable\":true,\"call_enable\":true," +
                "\"ios_mail_enable\":true,\"msg_enable\":true}",
            json
        )
    }

    @Test
    fun whitelistChunkHeaderCarriesTotalAndIndex() {
        // Force multiple chunks so the [0x04, total, index] header is exercised.
        val apps = (0 until 40).map {
            G1CommandEncoder.WhitelistApp(id = "com.example.app$it", name = "App $it")
        }
        val chunks = G1CommandEncoder.notificationWhitelist(apps)

        assertTrue(chunks.size > 1)
        chunks.forEachIndexed { index, chunk ->
            assertEquals(0x04, chunk[0].toInt() and 0xFF)
            assertEquals(chunks.size, chunk[1].toInt() and 0xFF)
            assertEquals(index, chunk[2].toInt() and 0xFF)
            assertTrue(chunk.size - 3 <= G1CommandEncoder.JSON_CHUNK_SIZE)
        }
    }

    // MARK: - Whole-screen text encoding

    @Test
    fun wholeScreenTextUsesNewContentStatusAnd176ByteChunks() {
        val text = "a".repeat(400)
        val packets = G1PacketEncoder.encodeWholeScreenText(text, seq = 5)

        assertEquals(3, packets.size)
        packets.forEachIndexed { index, packet ->
            assertEquals(
                G1PacketEncoder.COMMAND_BYTE.toInt() and 0xFF,
                packet[0].toInt() and 0xFF
            )
            assertEquals(5, packet[1].toInt() and 0xFF)
            // NOTE: header byte 2 is the chunk COUNT (3), not count - 1 like the
            // paged path's maxSeq. Bug-compatible with the Swift encoder and its
            // test; pending hardware validation on real glasses.
            assertEquals(3, packet[2].toInt() and 0xFF)
            assertEquals(index, packet[3].toInt() and 0xFF)
            assertEquals(
                G1ScreenStatus.NEW_CONTENT_PAGE.raw.toInt() and 0xFF,
                packet[4].toInt() and 0xFF
            )
            assertTrue(
                packet.size - G1PacketEncoder.HEADER_LENGTH <=
                    G1PacketEncoder.WHOLE_SCREEN_CHUNK_SIZE
            )
        }
        assertEquals(176, packets[0].size - G1PacketEncoder.HEADER_LENGTH)
    }

    @Test
    fun wholeScreenNewCharPosAndPageBytesAreSwiftCompatible() {
        val packets = G1PacketEncoder.encodeWholeScreenText("hi", seq = 2)
        assertEquals(1, packets.size)
        val p = packets[0]
        assertEquals(0, p[5].toInt())  // new_char_pos hi — always 0
        assertEquals(0, p[6].toInt())  // new_char_pos lo — always 0
        // NOTE: currentPage is hard-coded 0 here (0-based) against maxPage 1
        // (1-based), unlike the paged path's 1-based currentPage. Replicates
        // the Swift source exactly; pending hardware validation.
        assertEquals(0, p[7].toInt())
        assertEquals(1, p[8].toInt())
    }

    @Test
    fun existingTextPageEncodingUnchanged() {
        // Regression guard: the hardware-proven paged path keeps 0x70 + 182-byte chunks.
        val packets = G1PacketEncoder.encodeTextPage("hello", currentPage = 2, maxPage = 3)
        assertEquals(1, packets.size)
        assertEquals(
            G1ScreenStatus.TEXT_PAGE.raw.toInt() and 0xFF,
            packets[0][4].toInt() and 0xFF
        )
        assertEquals(2, packets[0][7].toInt())
        assertEquals(3, packets[0][8].toInt())
    }

    @Test
    fun textPageFullHeaderGoldenVector() {
        val packets = G1PacketEncoder.encodeTextPage("hi", currentPage = 1, maxPage = 1)
        assertEquals(1, packets.size)
        assertBytes(
            bytes(0x4E, 0x00, 0x00, 0x00, 0x70, 0x00, 0x00, 0x01, 0x01, 'h'.code, 'i'.code),
            packets[0]
        )
    }

    @Test
    fun textPageUsesExpectedHeaderAndPacketSize() {
        // From NativeConversationTests.testG1PacketEncoderUsesExpectedHeaderAndPacketSize
        val packets = G1PacketEncoder.encodeTextPage("a".repeat(400))

        assertTrue(packets.size > 1)
        assertEquals(
            G1PacketEncoder.COMMAND_BYTE.toInt() and 0xFF,
            packets[0][0].toInt() and 0xFF
        )
        assertEquals(
            G1ScreenStatus.TEXT_PAGE.raw.toInt() and 0xFF,
            packets[0][4].toInt() and 0xFF
        )
        assertTrue(packets.all { it.size <= G1PacketEncoder.MAX_PACKET_LENGTH })
    }

    @Test
    fun textPageMaxSeqIsChunkCountMinusOneAndSeqIncrements() {
        // 400 bytes / 182 = 3 chunks -> maxSeq 2.
        val packets = G1PacketEncoder.encodeTextPage("a".repeat(400))
        assertEquals(3, packets.size)
        packets.forEachIndexed { index, packet ->
            assertEquals(0x4E, packet[0].toInt() and 0xFF)
            assertEquals(0x00, packet[1].toInt() and 0xFF)  // syncSeq fixed 0
            assertEquals(2, packet[2].toInt() and 0xFF)     // maxSeq = count - 1
            assertEquals(index, packet[3].toInt() and 0xFF)
        }
        assertEquals(182, packets[0].size - G1PacketEncoder.HEADER_LENGTH)
        assertEquals(400 - 364, packets[2].size - G1PacketEncoder.HEADER_LENGTH)
    }

    @Test
    fun textPageEmptyTextStillProducesOneHeaderOnlyPacket() {
        val packets = G1PacketEncoder.encodeTextPage("")
        assertEquals(1, packets.size)
        assertEquals(G1PacketEncoder.HEADER_LENGTH, packets[0].size)
        assertEquals(0, packets[0][2].toInt())  // maxSeq
        assertEquals(0, packets[0][3].toInt())  // seq
    }

    @Test
    fun textPageEncodesMultiByteUtf8ByByteLength() {
        // Chunking is over UTF-8 BYTES, not characters, exactly as in Swift.
        val text = "é".repeat(100)  // 200 UTF-8 bytes
        val packets = G1PacketEncoder.encodeTextPage(text)
        assertEquals(2, packets.size)
        assertEquals(182, packets[0].size - G1PacketEncoder.HEADER_LENGTH)
        assertEquals(18, packets[1].size - G1PacketEncoder.HEADER_LENGTH)
    }

    @Test
    fun screenStatusRawValues() {
        assertEquals(0x01, G1ScreenStatus.NEW_CONTENT.raw.toInt() and 0xFF)
        assertEquals(0x30, G1ScreenStatus.DISPLAYING.raw.toInt() and 0xFF)
        assertEquals(0x40, G1ScreenStatus.COMPLETE.raw.toInt() and 0xFF)
        assertEquals(0x50, G1ScreenStatus.MANUAL_MODE.raw.toInt() and 0xFF)
        assertEquals(0x60, G1ScreenStatus.NETWORK_ERROR.raw.toInt() and 0xFF)
        assertEquals(0x70, G1ScreenStatus.TEXT_PAGE.raw.toInt() and 0xFF)
        assertEquals(0x71, G1ScreenStatus.NEW_CONTENT_PAGE.raw.toInt() and 0xFF)
    }

    // MARK: - Status decoding

    @Test
    fun decodesHeadAndCaseEvents() {
        assertEquals(G1StatusEvent.HeadUp, G1StatusDecoder.decode(bytes(0xF5, 0x02)))
        assertEquals(G1StatusEvent.HeadDown, G1StatusDecoder.decode(bytes(0xF5, 0x03)))
        assertEquals(
            G1StatusEvent.CaseState(G1CaseState.REMOVED),
            G1StatusDecoder.decode(bytes(0xF5, 0x06))
        )
        assertEquals(
            G1StatusEvent.CaseState(G1CaseState.REMOVED),
            G1StatusDecoder.decode(bytes(0xF5, 0x07))
        )
        assertEquals(
            G1StatusEvent.CaseState(G1CaseState.OPEN),
            G1StatusDecoder.decode(bytes(0xF5, 0x08))
        )
        assertEquals(
            G1StatusEvent.CaseState(G1CaseState.CLOSED),
            G1StatusDecoder.decode(bytes(0xF5, 0x0B))
        )
        assertEquals(
            G1StatusEvent.CaseCharging(true),
            G1StatusDecoder.decode(bytes(0xF5, 0x0E, 0x01))
        )
        assertEquals(
            G1StatusEvent.CaseBatteryPercent(88),
            G1StatusDecoder.decode(bytes(0xF5, 0x0F, 88))
        )
    }

    @Test
    fun decodesBatteryResponse() {
        assertEquals(
            G1StatusEvent.Battery(percent = 76, isCharging = true),
            G1StatusDecoder.decode(bytes(0x2C, 0x66, 76, 0x01, 0x10, 0x0E))
        )
        assertNull(G1StatusDecoder.decode(bytes(0x2C, 0x00, 76)))
    }

    @Test
    fun batteryPercentClampsToHundred() {
        assertEquals(
            G1StatusEvent.Battery(percent = 100, isCharging = false),
            G1StatusDecoder.decode(bytes(0x2C, 0x66, 200, 0x00, 0x00, 0x00))
        )
        assertEquals(
            G1StatusEvent.CaseBatteryPercent(100),
            G1StatusDecoder.decode(bytes(0xF5, 0x0F, 250))
        )
    }

    @Test
    fun decodesAcks() {
        assertEquals(
            G1StatusEvent.Ack(command = 0x4D, success = true),
            G1StatusDecoder.decode(bytes(0x4D, 0xC9))
        )
        assertEquals(
            G1StatusEvent.Ack(command = 0x26, success = true),
            G1StatusDecoder.decode(bytes(0x26, 0xC9))
        )
        assertEquals(
            G1StatusEvent.Ack(command = 0x06, success = true),
            G1StatusDecoder.decode(bytes(0x06, 0x07))
        )
        assertEquals(
            G1StatusEvent.Ack(command = 0x4D, success = false),
            G1StatusDecoder.decode(bytes(0x4D, 0x00))
        )
        assertNull(G1StatusDecoder.decode(bytes(0xF1, 0x00, 0x01)))
    }

    @Test
    fun decodesAckContinueAsSuccess() {
        assertEquals(
            G1StatusEvent.Ack(command = 0x4D, success = true),
            G1StatusDecoder.decode(bytes(0x4D, 0xCB))
        )
    }

    @Test
    fun decodesFirmwareInfoUpToNulTerminator() {
        val frame = bytes(0x6E) + "1.5.0".toByteArray() + bytes(0x00, 0x41)
        assertEquals(G1StatusEvent.FirmwareInfo("1.5.0"), G1StatusDecoder.decode(frame))
    }

    @Test
    fun decodesNothingForEmptyOrUnknownFrames() {
        assertNull(G1StatusDecoder.decode(ByteArray(0)))
        assertNull(G1StatusDecoder.decode(bytes(0xAA, 0xBB)))
        assertNull(G1StatusDecoder.decode(bytes(0x4D)))       // too short for ACK
        assertNull(G1StatusDecoder.decode(bytes(0xF5)))       // too short for F5
        assertNull(G1StatusDecoder.decode(bytes(0xF5, 0x0F))) // 0x0F needs a payload byte
    }

    @Test
    fun decodesTouchpadFrames() {
        assertEquals(
            G1TouchpadFrame(0, G1TouchpadSide.LEFT),
            G1StatusDecoder.decodeTouchpad(bytes(0xF5, 0x00), G1TouchpadSide.LEFT)
        )
        assertEquals(
            G1TouchpadFrame(1, G1TouchpadSide.RIGHT),
            G1StatusDecoder.decodeTouchpad(bytes(0xF5, 0x01), G1TouchpadSide.RIGHT)
        )
        assertEquals(
            G1TouchpadFrame(23, G1TouchpadSide.RIGHT),
            G1StatusDecoder.decodeTouchpad(bytes(0xF5, 23), G1TouchpadSide.RIGHT)
        )
        assertEquals(
            G1TouchpadFrame(24, G1TouchpadSide.RIGHT),
            G1StatusDecoder.decodeTouchpad(bytes(0xF5, 24), G1TouchpadSide.RIGHT)
        )
        // Head gestures stay status events, not touchpad frames.
        assertNull(G1StatusDecoder.decodeTouchpad(bytes(0xF5, 0x02), G1TouchpadSide.LEFT))
        assertNull(G1StatusDecoder.decodeTouchpad(bytes(0x2C, 0x66), G1TouchpadSide.LEFT))
    }

    // MARK: - Touchpad routing

    @Test
    fun routesTouchpadWithoutActiveAnswer() {
        fun route(i: Int, s: G1TouchpadSide) = G1TouchpadRouter.route(i, s, hasActiveAnswer = false)

        assertEquals(G1TouchpadAction.Exit, route(0, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.Exit, route(0, G1TouchpadSide.RIGHT))
        // Right taps start EvenAI; left is unhandled (shell maps it to pause/resume).
        assertEquals(G1TouchpadAction.EvenAIStart, route(1, G1TouchpadSide.RIGHT))
        assertEquals(G1TouchpadAction.Unknown(1), route(1, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.HeadUp, route(2, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.HeadDown, route(3, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.EvenAIStart, route(23, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.EvenAIRecordOver, route(24, G1TouchpadSide.RIGHT))
        assertEquals(G1TouchpadAction.Unknown(99), route(99, G1TouchpadSide.LEFT))
    }

    @Test
    fun routesTouchpadWithActiveAnswerAsPageNavigation() {
        fun route(i: Int, s: G1TouchpadSide) = G1TouchpadRouter.route(i, s, hasActiveAnswer = true)

        assertEquals(G1TouchpadAction.PreviousPage, route(1, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.NextPage, route(1, G1TouchpadSide.RIGHT))
        // Everything else is unaffected by the answer flag.
        assertEquals(G1TouchpadAction.Exit, route(0, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.HeadUp, route(2, G1TouchpadSide.RIGHT))
        assertEquals(G1TouchpadAction.EvenAIStart, route(23, G1TouchpadSide.LEFT))
        assertEquals(G1TouchpadAction.EvenAIRecordOver, route(24, G1TouchpadSide.LEFT))
    }

    // MARK: - HUD pagination

    @Test
    fun hudPresenterPaginatesAndPacketizesAnswerText() {
        // From NativeConversationTests.testG1HudPresenterPaginatesAndPacketizesAnswerText
        val pages = G1HudPresenter(HudPaginator(maxCharactersPerPage = 24))
            .textPages("Helix streams concise answer pages to the Even G1 display.")

        assertTrue(pages.size > 1)
        assertEquals(1, pages.first().pageNumber)
        assertEquals(pages.size, pages.last().pageCount)
        assertTrue(pages.all { page ->
            page.packets.all { it.size <= G1PacketEncoder.MAX_PACKET_LENGTH }
        })
        assertEquals(
            G1ScreenStatus.TEXT_PAGE.raw.toInt() and 0xFF,
            pages.first().packets.first()[4].toInt() and 0xFF
        )
    }

    @Test
    fun hudPresenterStampsOneBasedCurrentPageAndPageCount() {
        val pages = G1HudPresenter(HudPaginator(maxCharactersPerPage = 24))
            .textPages("Helix streams concise answer pages to the Even G1 display.")

        pages.forEachIndexed { index, page ->
            assertEquals(index + 1, page.pageNumber)
            page.packets.forEach { packet ->
                assertEquals(index + 1, packet[7].toInt() and 0xFF)
                assertEquals(pages.size, packet[8].toInt() and 0xFF)
            }
        }
    }

    @Test
    fun paginatorGreedilyWrapsOnWordBoundaries() {
        val pages = HudPaginator(maxCharactersPerPage = 10).pages("one two three four five")
        assertEquals(listOf("one two", "three four", "five"), pages)
        pages.forEach { assertTrue(it.length <= 10) }
    }

    @Test
    fun paginatorEmitsOverlongWordOnItsOwnPage() {
        // A single word longer than the budget overflows its page — Swift behavior.
        val pages = HudPaginator(maxCharactersPerPage = 5).pages("tiny enormouswordhere ok")
        assertEquals(listOf("tiny", "enormouswordhere", "ok"), pages)
    }

    @Test
    fun paginatorReturnsSingleEmptyPageForEmptyText() {
        assertEquals(listOf(""), HudPaginator().pages(""))
        assertEquals(listOf(""), HudPaginator().pages("   "))
    }

    @Test
    fun paginatorDefaultBudgetKeepsShortAnswersOnOnePage() {
        val pages = HudPaginator().pages("Yes, the meeting moved to Thursday at ten.")
        assertEquals(1, pages.size)
        assertEquals("Yes, the meeting moved to Thursday at ten.", pages[0])
    }

    // MARK: - Transport

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportPreservesFifoOrderAcrossConcurrentSends() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer)

        (0 until 10).map { value ->
            async {
                transport.send(
                    G1Command(
                        bytes = bytes(0x25, value),
                        sides = listOf(G1Side.LEFT),
                        postDelayMillis = 0,
                    )
                )
            }
        }.awaitAll()

        val written = writer.writes().map { it.bytes[1].toInt() }
        assertEquals(10, written.size)
        // FIFO under the queue mutex: whatever enqueue order won, packets must
        // not interleave — each command's bytes appear exactly once.
        assertEquals(10, written.toSet().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportSequentialSendsStayOrdered() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer)

        for (value in 0 until 5) {
            transport.send(
                G1Command(
                    bytes = bytes(0x25, value),
                    sides = listOf(G1Side.LEFT),
                    postDelayMillis = 0,
                )
            )
        }

        assertEquals(
            listOf(0, 1, 2, 3, 4),
            writer.writes().map { it.bytes[1].toInt() }
        )
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportAckRequiredSucceedsWhenAckArrives() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 2_000)
        writer.onWrite = { packet, side ->
            // Echo an ACK for the init command from the written side.
            if (packet.isNotEmpty() && packet[0] == 0x4D.toByte()) {
                transport.handleInbound(bytes(0x4D, 0xC9), side)
            }
        }

        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT, G1Side.RIGHT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )

        assertTrue(success)
        assertEquals(2, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportAckTimeoutRetriesThenFails() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 50)

        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )

        assertTrue(!success)
        assertEquals(G1CommandTransport.MAX_ATTEMPTS, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportAckSucceedsOnRetryAfterFirstAttemptTimesOut() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 100)
        var attempts = 0
        writer.onWrite = { _, side ->
            attempts += 1
            if (attempts >= 2) {
                transport.handleInbound(bytes(0x4D, 0xC9), side)
            }
        }

        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )

        assertTrue(success)
        assertEquals(2, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportIgnoresAckForADifferentCommand() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 50)
        writer.onWrite = { _, side ->
            // Wrong command byte: must NOT resolve the 0x4D waiter.
            transport.handleInbound(bytes(0x26, 0xC9), side)
        }

        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )

        assertTrue(!success)
        assertEquals(G1CommandTransport.MAX_ATTEMPTS, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportPropagatesAckFailureStatus() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 500)
        writer.onWrite = { _, side ->
            // A NAK: decoded as Ack(success = false) — no retry saves it.
            transport.handleInbound(bytes(0x4D, 0x00), side)
        }

        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )

        assertTrue(!success)
        assertEquals(G1CommandTransport.MAX_ATTEMPTS, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportStaleAckDoesNotResolveALaterWaiter() = runTest {
        // Regression guard for the generation-token fix: an ACK that arrives
        // after its command already timed out must not satisfy the next one.
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 50)

        val first = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )
        assertTrue(!first)

        // Late ACK for the command that already gave up.
        transport.handleInbound(bytes(0x4D, 0xC9), G1Side.LEFT)

        val second = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )
        // The stale ACK was dropped (no waiter registered at the time), so the
        // second command must run its own full retry budget and fail.
        assertTrue(!second)
        assertEquals(G1CommandTransport.MAX_ATTEMPTS * 2, writer.writes().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportResetResolvesOutstandingWaitersWithoutWaitingForTimeout() = runTest {
        // A disconnect must free every in-flight waiter immediately rather than
        // leaving the send parked for the full (here: very long) ACK timeout.
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer, ackTimeoutMillis = 10_000)
        writer.onWrite = { _, _ ->
            // Simulate the BLE stack dropping the link mid-write.
            transport.reset()
        }

        val start = currentTime
        val success = transport.send(
            G1Command(
                bytes = bytes(0x4D, 0xFB),
                sides = listOf(G1Side.LEFT),
                ackPolicy = G1AckPolicy.Required(0x4D),
                postDelayMillis = 0,
            )
        )
        val elapsed = currentTime - start

        assertTrue(!success)
        assertEquals(G1CommandTransport.MAX_ATTEMPTS, writer.writes().size)
        // Only the retry backoffs elapsed — never an ACK timeout.
        assertTrue(
            "reset should short-circuit the ACK timeout, but $elapsed ms elapsed",
            elapsed < 10_000
        )
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportFireAndForgetWritesBothSidesInOrder() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer)

        transport.send(G1Command(bytes = bytes(0x25, 1), postDelayMillis = 0))

        val writes = writer.writes()
        assertEquals(2, writes.size)
        assertEquals(G1Side.LEFT, writes[0].side)
        assertEquals(G1Side.RIGHT, writes[1].side)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun transportSendScreenWritesLeftThenRightWithInterSideDelay() = runTest {
        val writer = RecordingWriter()
        val transport = G1CommandTransport(writer)
        val packets = G1PacketEncoder.encodeTextPage("a".repeat(400))
        assertEquals(3, packets.size)

        val start = currentTime
        val ok = transport.sendScreen(packets)
        val elapsed = currentTime - start

        assertTrue(ok)
        val writes = writer.writes()
        assertEquals(6, writes.size)
        assertEquals(List(3) { G1Side.LEFT } + List(3) { G1Side.RIGHT }, writes.map { it.side })
        // Left packets keep their sequence, then the right lens repeats it.
        assertEquals(listOf(0, 1, 2, 0, 1, 2), writes.map { it.bytes[3].toInt() })
        // The 400 ms inter-side settle is load-bearing and must be present.
        assertTrue(
            "expected >= ${G1CommandTransport.INTER_SIDE_DELAY_MILLIS}ms of delay, got $elapsed",
            elapsed >= G1CommandTransport.INTER_SIDE_DELAY_MILLIS
        )
    }

    @Test
    fun interSideDelayConstantIs400ms() {
        // Guard: memory/reference_evenai_400ms_delay.md — do not remove or shorten.
        assertEquals(400L, G1CommandTransport.INTER_SIDE_DELAY_MILLIS)
    }
}

/**
 * In-memory [G1PacketWriter] used by the transport tests.
 *
 * [onWrite] is a suspend hook so a test can echo an inbound ACK without needing
 * an external scope; it runs on the writer's own coroutine, i.e. inside the
 * transport's queue lock, exactly like a BLE callback landing mid-write.
 */
private class RecordingWriter : G1PacketWriter {
    private val lock = Mutex()
    private val recorded = mutableListOf<G1SentPacket>()

    var onWrite: (suspend (ByteArray, G1Side) -> Unit)? = null

    override suspend fun write(bytes: ByteArray, side: G1Side): Boolean {
        lock.withLock { recorded.add(G1SentPacket(bytes, side)) }
        onWrite?.invoke(bytes, side)
        return true
    }

    suspend fun writes(): List<G1SentPacket> = lock.withLock { recorded.toList() }
}
