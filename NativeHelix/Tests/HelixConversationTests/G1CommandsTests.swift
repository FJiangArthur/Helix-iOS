import XCTest
import HelixG1

final class G1CommandsTests: XCTestCase {
    private let encoder = G1CommandEncoder()
    private let decoder = G1StatusDecoder()

    // MARK: - Encoder byte layouts

    func testCoreCommandByteLayouts() {
        XCTAssertEqual(encoder.initHandshake(), [0x4D, 0xFB])
        XCTAssertEqual(encoder.heartbeat(counter: 7), [0x25, 7, 0x00, 0x04, 7])
        XCTAssertEqual(encoder.batteryPoll(), [0x2C])
        XCTAssertEqual(encoder.silentModeOff(), [0x03, 0x0A])
        XCTAssertEqual(encoder.wearDetectionOff(), [0x27, 0x00])
        XCTAssertEqual(encoder.exitAllFunctions(), [0x18])
        XCTAssertEqual(encoder.firmwareInfoRequest(), [0x6E, 0x74])
        XCTAssertEqual(encoder.microphone(enabled: true), [0x0E, 0x01])
        XCTAssertEqual(encoder.microphone(enabled: false), [0x0E, 0x00])
    }

    func testBrightnessClampsRange() {
        XCTAssertEqual(encoder.brightness(level: 30, autoBrightness: true), [0x01, 30, 0x01])
        XCTAssertEqual(encoder.brightness(level: 99, autoBrightness: false), [0x01, 63, 0x00])
        XCTAssertEqual(encoder.brightness(level: -5, autoBrightness: false), [0x01, 0, 0x00])
    }

    func testHeadUpAngleClampsRange() {
        XCTAssertEqual(encoder.headUpAngle(degrees: 30), [0x0B, 30, 0x01])
        XCTAssertEqual(encoder.headUpAngle(degrees: 75), [0x0B, 60, 0x01])
        XCTAssertEqual(encoder.headUpAngle(degrees: -1), [0x0B, 0, 0x01])
    }

    func testDisplayPositionLayoutAndClamping() {
        XCTAssertEqual(
            encoder.displayPosition(height: 4, depth: 5, counter: 9),
            [0x26, 0x08, 0x00, 9, 0x02, 0x01, 4, 5]
        )
        XCTAssertEqual(
            encoder.displayPosition(height: 20, depth: 20, counter: 0),
            [0x26, 0x08, 0x00, 0, 0x02, 0x01, 8, 9]
        )
    }

    func testDateTimeSyncLayout() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let packet = encoder.dateTimeSync(date: date, counter: 3)

        XCTAssertEqual(packet.count, 17)
        XCTAssertEqual(Array(packet.prefix(5)), [0x06, 0x15, 0x00, 3, 0x01])
        let seconds = packet[5...8].enumerated().reduce(UInt32(0)) { acc, pair in
            acc | (UInt32(pair.element) << (8 * pair.offset))
        }
        XCTAssertEqual(seconds, 1_000_000)
    }

    // MARK: - Chunked JSON commands

    func testNotificationChunksCarryHeaderAndReassemble() throws {
        let longMessage = String(repeating: "insight ", count: 60)
        let chunks = try encoder.notification(
            messageID: 12,
            appIdentifier: "com.artjiang.helix",
            displayName: "Helix",
            title: "Answer ready",
            message: longMessage,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertGreaterThan(chunks.count, 1)
        let total = chunks[0][2]
        XCTAssertEqual(Int(total), chunks.count)
        for (index, chunk) in chunks.enumerated() {
            XCTAssertEqual(chunk[0], 0x4B)
            XCTAssertEqual(chunk[1], 0x00)
            XCTAssertEqual(Int(chunk[3]), index)
            XCTAssertLessThanOrEqual(chunk.count - 4, G1CommandEncoder.jsonChunkSize)
        }

        let json = Data(chunks.flatMap { Array($0.dropFirst(4)) })
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let notification = try XCTUnwrap(object["ncs_notification"] as? [String: Any])
        XCTAssertEqual(notification["title"] as? String, "Answer ready")
        XCTAssertEqual(notification["app_identifier"] as? String, "com.artjiang.helix")
        XCTAssertEqual(object["type"] as? String, "Add")
    }

    func testWhitelistChunksReassembleToValidJSON() throws {
        let chunks = try encoder.notificationWhitelist(
            appIdentifiers: [(id: "com.artjiang.helix", name: "Helix")]
        )

        for chunk in chunks {
            XCTAssertEqual(chunk[0], 0x04)
        }
        let json = Data(chunks.flatMap { Array($0.dropFirst(3)) })
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(object["calendar_enable"] as? Bool, true)
        let app = try XCTUnwrap(object["app"] as? [String: Any])
        XCTAssertEqual((app["list"] as? [[String: String]])?.first?["id"], "com.artjiang.helix")
    }

    // MARK: - Whole-screen text encoding

    func testWholeScreenTextUsesNewContentStatusAnd176ByteChunks() {
        let text = String(repeating: "a", count: 400)
        let packets = G1PacketEncoder().encodeWholeScreenText(text, seq: 5)

        XCTAssertEqual(packets.count, 3)
        for (index, packet) in packets.enumerated() {
            XCTAssertEqual(packet[0], G1PacketEncoder.commandByte)
            XCTAssertEqual(packet[1], 5)
            XCTAssertEqual(packet[2], 3)
            XCTAssertEqual(Int(packet[3]), index)
            XCTAssertEqual(packet[4], G1ScreenStatus.newContent.rawValue)
            XCTAssertLessThanOrEqual(packet.count - 9, G1PacketEncoder.wholeScreenChunkSize)
        }
        XCTAssertEqual(packets[0].count - 9, 176)
    }

    func testExistingTextPageEncodingUnchanged() {
        // Regression guard: the hardware-proven paged path keeps 0x70 + 182-byte chunks.
        let packets = G1PacketEncoder().encodeTextPage("hello", currentPage: 2, maxPage: 3)
        XCTAssertEqual(packets.count, 1)
        XCTAssertEqual(packets[0][4], G1ScreenStatus.textPage.rawValue)
        XCTAssertEqual(packets[0][7], 2)
        XCTAssertEqual(packets[0][8], 3)
    }

    // MARK: - Status decoding

    func testDecodesHeadAndCaseEvents() {
        XCTAssertEqual(decoder.decode([0xF5, 0x02]), .headUp)
        XCTAssertEqual(decoder.decode([0xF5, 0x03]), .headDown)
        XCTAssertEqual(decoder.decode([0xF5, 0x06]), .caseState(.removed))
        XCTAssertEqual(decoder.decode([0xF5, 0x08]), .caseState(.open))
        XCTAssertEqual(decoder.decode([0xF5, 0x0B]), .caseState(.closed))
        XCTAssertEqual(decoder.decode([0xF5, 0x0E, 0x01]), .caseCharging(true))
        XCTAssertEqual(decoder.decode([0xF5, 0x0F, 88]), .caseBatteryPercent(88))
    }

    func testDecodesBatteryResponse() {
        XCTAssertEqual(
            decoder.decode([0x2C, 0x66, 76, 0x01, 0x10, 0x0E]),
            .battery(percent: 76, isCharging: true)
        )
        XCTAssertNil(decoder.decode([0x2C, 0x00, 76]))
    }

    func testDecodesAcks() {
        XCTAssertEqual(decoder.decode([0x4D, 0xC9]), .ack(command: 0x4D, success: true))
        XCTAssertEqual(decoder.decode([0x26, 0xC9]), .ack(command: 0x26, success: true))
        XCTAssertEqual(decoder.decode([0x06, 0x07]), .ack(command: 0x06, success: true))
        XCTAssertEqual(decoder.decode([0x4D, 0x00]), .ack(command: 0x4D, success: false))
        XCTAssertNil(decoder.decode([0xF1, 0x00, 0x01]))
    }

    // MARK: - Transport

    func testTransportPreservesFIFOOrderAcrossConcurrentSends() async {
        let writer = RecordingWriter()
        let transport = G1CommandTransport(writer: writer)

        await withTaskGroup(of: Void.self) { group in
            for value in UInt8(0)..<UInt8(10) {
                group.addTask {
                    await transport.send(G1Command(bytes: [0x25, value], sides: [.left], postDelayNs: 0))
                }
            }
        }

        let written = await writer.writes.map { $0.bytes[1] }
        XCTAssertEqual(written.count, 10)
        // FIFO within the actor: whatever enqueue order won, packets must not interleave —
        // each command's bytes appear exactly once.
        XCTAssertEqual(Set(written).count, 10)
    }

    func testTransportSequentialSendsStayOrdered() async {
        let writer = RecordingWriter()
        let transport = G1CommandTransport(writer: writer)

        for value in UInt8(0)..<UInt8(5) {
            await transport.send(G1Command(bytes: [0x25, value], sides: [.left], postDelayNs: 0))
        }

        let written = await writer.writes.map { $0.bytes[1] }
        XCTAssertEqual(written, [0, 1, 2, 3, 4])
    }

    func testTransportAckRequiredSucceedsWhenAckArrives() async {
        let writer = RecordingWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 2_000_000_000)
        await writer.setOnWrite { bytes, side in
            // Echo an ACK for the init command from the written side.
            if bytes.first == 0x4D {
                Task { await transport.handleInbound([0x4D, 0xC9], from: side) }
            }
        }

        let success = await transport.send(
            G1Command(bytes: [0x4D, 0xFB], sides: [.left, .right], ackPolicy: .required(command: 0x4D), postDelayNs: 0)
        )
        XCTAssertTrue(success)
    }

    func testTransportAckTimeoutRetriesThenFails() async {
        let writer = RecordingWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 50_000_000)

        let success = await transport.send(
            G1Command(bytes: [0x4D, 0xFB], sides: [.left], ackPolicy: .required(command: 0x4D), postDelayNs: 0)
        )

        XCTAssertFalse(success)
        let attempts = await writer.writes.count
        XCTAssertEqual(attempts, G1CommandTransport.maxAttempts)
    }
}

private actor RecordingWriter: G1PacketWriter {
    private(set) var writes: [(bytes: [UInt8], side: G1Side)] = []
    private var onWrite: (@Sendable ([UInt8], G1Side) -> Void)?

    func setOnWrite(_ handler: @escaping @Sendable ([UInt8], G1Side) -> Void) {
        onWrite = handler
    }

    func write(_ bytes: [UInt8], to side: G1Side) async {
        writes.append((bytes, side))
        onWrite?(bytes, side)
    }
}
