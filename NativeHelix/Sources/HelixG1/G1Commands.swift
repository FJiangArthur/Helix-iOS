import Foundation

// MARK: - Command encoding

/// Builds outbound G1 BLE command packets. Byte layouts follow the MentraOS
/// reference implementation (mobile/modules/bluetooth-sdk, sgcs/G1.swift|kt),
/// which is the most complete open-source G1 driver.
public struct G1CommandEncoder: Sendable {
    /// Max JSON payload per chunk for chunked-JSON commands (0x04, 0x4B).
    public static let jsonChunkSize = 176

    public init() {}

    /// Init handshake sent after both characteristics are ready.
    /// Expects ACK `0x4D 0xC9`.
    public func initHandshake() -> [UInt8] {
        [0x4D, 0xFB]
    }

    /// Keep-alive; send every 10–20 s. The counter is echoed back.
    public func heartbeat(counter: UInt8) -> [UInt8] {
        [0x25, counter, 0x00, 0x04, counter]
    }

    /// Battery status request. Response: `[0x2C, 0x66, batt%, flags, vLo, vHi]`.
    public func batteryPoll() -> [UInt8] {
        [0x2C]
    }

    /// Brightness 0–63 plus auto-brightness flag.
    public func brightness(level: Int, autoBrightness: Bool) -> [UInt8] {
        [0x01, UInt8(clamping: max(0, min(63, level))), autoBrightness ? 0x01 : 0x00]
    }

    /// Disables silent mode (part of the init sequence).
    public func silentModeOff() -> [UInt8] {
        [0x03, 0x0A]
    }

    /// Disables firmware wear detection (part of the init sequence).
    public func wearDetectionOff() -> [UInt8] {
        [0x27, 0x00]
    }

    /// Head-up detection angle, 0–60 degrees.
    public func headUpAngle(degrees: Int) -> [UInt8] {
        [0x0B, UInt8(clamping: max(0, min(60, degrees))), 0x01]
    }

    /// HUD position. Height 0 (bottom) – 8 (top); depth 0 (far) – 9 (near).
    /// Expects ACK `0x06`.
    public func displayPosition(height: Int, depth: Int, counter: UInt8) -> [UInt8] {
        [
            0x26,
            0x08,
            0x00,
            counter,
            0x02,
            0x01,
            UInt8(clamping: max(0, min(8, height))),
            UInt8(clamping: max(0, min(9, depth)))
        ]
    }

    /// Glasses-side microphone stream on/off (0xF1 PCM frames follow when on).
    public func microphone(enabled: Bool) -> [UInt8] {
        [0x0E, enabled ? 0x01 : 0x00]
    }

    /// Clears the screen and exits the current firmware function.
    public func exitAllFunctions() -> [UInt8] {
        [0x18]
    }

    /// Firmware info request.
    public func firmwareInfoRequest() -> [UInt8] {
        [0x6E, 0x74]
    }

    /// Date/time sync so the firmware dashboard shows the right clock.
    /// Layout: `[0x06, 0x15, 0x00, counter, 0x01, epoch32 LE, epoch64ms LE]`
    /// (0x15 = fixed length byte 21). Expects ACK `0x07/0x90/0x0C`.
    public func dateTimeSync(date: Date, counter: UInt8) -> [UInt8] {
        let seconds = UInt32(clamping: Int64(date.timeIntervalSince1970))
        let millis = UInt64(clamping: Int64(date.timeIntervalSince1970 * 1000))
        var packet: [UInt8] = [0x06, 0x15, 0x00, counter, 0x01]
        packet += withUnsafeBytes(of: seconds.littleEndian) { Array($0) }
        packet += withUnsafeBytes(of: millis.littleEndian) { Array($0) }
        return packet
    }

    /// Notification whitelist config (chunked JSON, command 0x04).
    /// Header per chunk: `[0x04, totalChunks, chunkIndex]`.
    public func notificationWhitelist(
        appIdentifiers: [(id: String, name: String)],
        calendarEnabled: Bool = true,
        callEnabled: Bool = true,
        messageEnabled: Bool = true,
        mailEnabled: Bool = true
    ) throws -> [[UInt8]] {
        let payload: [String: Any] = [
            "calendar_enable": calendarEnabled,
            "call_enable": callEnabled,
            "msg_enable": messageEnabled,
            "ios_mail_enable": mailEnabled,
            "app": [
                "list": appIdentifiers.map { ["id": $0.id, "name": $0.name] },
                "enable": true
            ]
        ]
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return chunkJSON(json) { total, index in [0x04, total, index] }
    }

    /// Phone-notification push (chunked JSON, command 0x4B).
    /// Header per chunk: `[0x4B, notifyId, totalChunks, chunkIndex]`.
    public func notification(
        messageID: Int,
        appIdentifier: String,
        displayName: String,
        title: String,
        subtitle: String = "",
        message: String,
        date: Date,
        notifyID: UInt8 = 0
    ) throws -> [[UInt8]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let payload: [String: Any] = [
            "ncs_notification": [
                "msg_id": messageID,
                "type": 1,
                "app_identifier": appIdentifier,
                "title": title,
                "subtitle": subtitle,
                "message": message,
                "time_s": Int(date.timeIntervalSince1970),
                "date": formatter.string(from: date),
                "display_name": displayName
            ],
            "type": "Add"
        ]
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return chunkJSON(json) { total, index in [0x4B, notifyID, total, index] }
    }

    private func chunkJSON(_ json: Data, header: (UInt8, UInt8) -> [UInt8]) -> [[UInt8]] {
        let bytes = Array(json)
        let chunks = stride(from: 0, to: max(bytes.count, 1), by: Self.jsonChunkSize).map { start in
            Array(bytes[start..<min(start + Self.jsonChunkSize, bytes.count)])
        }
        let total = UInt8(clamping: chunks.count)
        return chunks.enumerated().map { index, chunk in
            header(total, UInt8(clamping: index)) + chunk
        }
    }
}

// MARK: - Status decoding

public enum G1CaseState: String, Sendable {
    case removed
    case open
    case closed
}

/// Typed inbound frames from the glasses that are not touchpad presses
/// (touchpad notifyIndex routing stays in `G1TouchpadRouter`).
public enum G1StatusEvent: Equatable, Sendable {
    case headUp
    case headDown
    case caseState(G1CaseState)
    case caseCharging(Bool)
    case caseBatteryPercent(Int)
    case battery(percent: Int, isCharging: Bool)
    case ack(command: UInt8, success: Bool)
    case firmwareInfo(String)
}

public struct G1StatusDecoder: Sendable {
    public static let ackSuccess: UInt8 = 0xC9
    public static let ackContinue: UInt8 = 0xCB

    public init() {}

    /// Decodes one inbound frame into a status event, or nil when the frame
    /// is not a status frame (mic data 0xF1, touchpad presses, etc.).
    public func decode(_ data: [UInt8]) -> G1StatusEvent? {
        guard let command = data.first else { return nil }

        switch command {
        case 0xF5:
            return decodeF5(data)
        case 0x2C:
            guard data.count >= 4, data[1] == 0x66 else { return nil }
            let percent = Int(data[2])
            let charging = data[3] & 0x01 == 0x01
            return .battery(percent: min(100, percent), isCharging: charging)
        case 0x4D, 0x26, 0x06, 0x0B, 0x01, 0x0E, 0x04, 0x03, 0x27:
            guard data.count >= 2 else { return nil }
            let status = data[1]
            if status == Self.ackSuccess || status == Self.ackContinue {
                return .ack(command: command, success: true)
            }
            // Datetime/dashboard replies use their own success codes.
            if command == 0x06, [0x07, 0x90, 0x0C].contains(status) {
                return .ack(command: command, success: true)
            }
            return .ack(command: command, success: false)
        case 0x6E:
            let body = data.dropFirst().prefix(while: { $0 != 0 })
            return .firmwareInfo(String(decoding: body, as: UTF8.self))
        default:
            return nil
        }
    }

    private func decodeF5(_ data: [UInt8]) -> G1StatusEvent? {
        guard data.count >= 2 else { return nil }
        switch data[1] {
        case 0x02: return .headUp
        case 0x03: return .headDown
        case 0x06, 0x07: return .caseState(.removed)
        case 0x08: return .caseState(.open)
        case 0x0B: return .caseState(.closed)
        case 0x0E:
            let charging = data.count > 2 && data[2] == 0x01
            return .caseCharging(charging)
        case 0x0F:
            guard data.count > 2 else { return nil }
            return .caseBatteryPercent(min(100, Int(data[2])))
        default:
            return nil
        }
    }
}

// MARK: - Serialized ACK-gated transport

public enum G1Side: String, CaseIterable, Sendable {
    case left = "L"
    case right = "R"
}

/// Writes raw bytes to one lens. The app shell backs this with
/// BluetoothManager; tests use an in-memory fake.
public protocol G1PacketWriter: Sendable {
    func write(_ bytes: [UInt8], to side: G1Side) async
}

/// One queued command with its delivery policy.
public struct G1Command: Sendable {
    public enum AckPolicy: Equatable, Sendable {
        /// Fire and forget (heartbeat, text chunks — pacing only).
        case none
        /// Wait for an ACK frame for `command` before proceeding.
        case required(command: UInt8)
    }

    public var bytes: [UInt8]
    public var sides: [G1Side]
    public var ackPolicy: AckPolicy
    /// Pause after the write (inter-chunk pacing).
    public var postDelayNs: UInt64

    public init(
        bytes: [UInt8],
        sides: [G1Side] = G1Side.allCases,
        ackPolicy: AckPolicy = .none,
        postDelayNs: UInt64 = 8_000_000
    ) {
        self.bytes = bytes
        self.sides = sides
        self.ackPolicy = ackPolicy
        self.postDelayNs = postDelayNs
    }
}

/// Serial, ACK-aware send path. Every outbound packet — config commands,
/// heartbeat, battery polls, and HUD text chunks — flows through this actor
/// so periodic timers can never interleave bytes into a multi-packet screen
/// write. ACK-required commands retry up to `maxAttempts` with `ackTimeout`.
public actor G1CommandTransport {
    public static let defaultAckTimeoutNs: UInt64 = 5_000_000_000
    public static let maxAttempts = 3

    private let writer: any G1PacketWriter
    private let ackTimeoutNs: UInt64
    private var ackWaiters: [G1Side: CheckedContinuation<Bool, Never>] = [:]
    private var pendingAckCommand: UInt8?
    /// Commands execute strictly in FIFO order by chaining onto the tail task.
    private var tail: Task<Void, Never>?

    public private(set) var sentLog: [(bytes: [UInt8], side: G1Side)] = []

    public init(
        writer: any G1PacketWriter,
        ackTimeoutNs: UInt64 = G1CommandTransport.defaultAckTimeoutNs
    ) {
        self.writer = writer
        self.ackTimeoutNs = ackTimeoutNs
    }

    /// Enqueues a command; returns once it (and everything before it) has
    /// been written — and ACKed, when required.
    @discardableResult
    public func send(_ command: G1Command) async -> Bool {
        let previous = tail
        let task = Task { [weak self] () -> Bool in
            await previous?.value
            guard let self else { return false }
            return await self.execute(command)
        }
        tail = Task { _ = await task.value }
        return await task.value
    }

    /// Feed inbound frames here so ACK waiters resolve.
    public func handleInbound(_ data: [UInt8], from side: G1Side) {
        guard let expected = pendingAckCommand,
              let event = G1StatusDecoder().decode(data),
              case .ack(let command, let success) = event,
              command == expected else { return }
        if let waiter = ackWaiters.removeValue(forKey: side) {
            waiter.resume(returning: success)
        }
    }

    /// Drops all waiters (call on disconnect).
    public func reset() {
        for waiter in ackWaiters.values {
            waiter.resume(returning: false)
        }
        ackWaiters = [:]
        pendingAckCommand = nil
    }

    private func execute(_ command: G1Command) async -> Bool {
        switch command.ackPolicy {
        case .none:
            for side in command.sides {
                await writer.write(command.bytes, to: side)
                sentLog.append((command.bytes, side))
            }
            try? await Task.sleep(nanoseconds: command.postDelayNs)
            return true

        case .required(let ackCommand):
            for attempt in 1...Self.maxAttempts {
                var allAcked = true
                for side in command.sides {
                    pendingAckCommand = ackCommand
                    await writer.write(command.bytes, to: side)
                    sentLog.append((command.bytes, side))
                    let acked = await waitForAck(from: side)
                    allAcked = allAcked && acked
                }
                pendingAckCommand = nil
                if allAcked {
                    try? await Task.sleep(nanoseconds: command.postDelayNs)
                    return true
                }
                if attempt < Self.maxAttempts {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            return false
        }
    }

    private func waitForAck(from side: G1Side) async -> Bool {
        let timeoutNs = ackTimeoutNs
        return await withCheckedContinuation { continuation in
            ackWaiters[side] = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await self?.timeoutWaiter(for: side)
            }
        }
    }

    private func timeoutWaiter(for side: G1Side) {
        if let waiter = ackWaiters.removeValue(forKey: side) {
            waiter.resume(returning: false)
        }
    }
}
