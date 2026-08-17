// ABOUTME: App-shell coordinator that wires BluetoothManager BLE events and
// ABOUTME: SpeechStreamRecognizer transcripts into the HelixRuntime pipeline.

import Foundation
import HelixCore
import HelixG1
import HelixRuntime
import Observation

struct DiscoveredGlassesPair: Identifiable, Equatable {
    let channelNumber: String
    var leftName: String
    var rightName: String
    var leftRssi: Int
    var rightRssi: Int

    var id: String { channelNumber }
    var pairKey: String { "Pair_\(channelNumber)" }
    var displayName: String { "G1 · Channel \(channelNumber)" }
    var signalSummary: String { "L \(leftRssi) dBm · R \(rightRssi) dBm" }
}

@MainActor
@Observable
final class HelixNativeBridge {
    private let runtime: HelixRuntimeDependencies
    private var isActivated = false

    private(set) var isScanning = false
    private(set) var discoveredPairs: [DiscoveredGlassesPair] = []
    private(set) var connectionPhase = "Not connected"
    private(set) var connectedDeviceName: String?
    private(set) var bluetoothError = ""
    private(set) var livePartialTranscript = ""
    private(set) var speechError = ""

    /// In-flight HUD page push; cancelled when a newer page supersedes it so
    /// packets from two pages never interleave on the glasses.
    private var hudSendTask: Task<Void, Never>?
    /// Serializes final-transcript processing so a fast second segment cannot
    /// overtake a slow first one and display the wrong answer.
    private var liveTranscriptTask: Task<Void, Never>?

    /// Delay between pushing a HUD page to the left and right lens. The G1
    /// firmware drops packets when both sides stream simultaneously.
    private static let interSideDelayNs: UInt64 = 400_000_000

    /// Serial ACK-gated send path. Every outbound packet (config, heartbeat,
    /// battery poll, HUD chunks) goes through this so periodic timers never
    /// interleave bytes into a multi-packet screen write.
    let transport: G1CommandTransport
    private let commandEncoder = G1CommandEncoder()
    private let statusDecoder = G1StatusDecoder()
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatCounter: UInt8 = 0
    private var positionCounter: UInt8 = 0
    private var notificationMessageID = 0
    let hudArbiter = HudArbiter()

    init(runtime: HelixRuntimeDependencies) {
        self.runtime = runtime
        self.transport = G1CommandTransport(writer: BluetoothPacketWriter())
    }

    var isGlassesConnected: Bool {
        runtime.g1DeviceState.leftLensConnected || runtime.g1DeviceState.rightLensConnected
    }

    // MARK: - Bluetooth lifecycle

    /// Must run at app startup so queued glassesConnected events (including
    /// OS-restored connections) drain into the runtime device state.
    func activate() {
        guard !isActivated else { return }
        isActivated = true
        runtime.insightCoordinator.onDisplay = { [weak self] insight in
            guard let self, self.isGlassesConnected else { return }
            Task {
                guard await self.hudArbiter.requestDisplay(.insight, durationSeconds: 10) else { return }
                self.runtime.g1DeviceState.presentText(insight.text)
                self.sendCurrentHudPage(priority: .insight)
            }
        }
        BluetoothManager.configure(
            eventHandler: { [weak self] eventName, arguments in
                Task { @MainActor in
                    self?.handleBleEvent(eventName, arguments: arguments)
                }
            },
            infoEventHandler: { [weak self] payload in
                Task { @MainActor in
                    self?.handleInfoEvent(payload)
                }
            }
        )
    }

    func startScan() {
        bluetoothError = ""
        discoveredPairs = []
        BluetoothManager.shared.startScan { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.isScanning = true
                    self?.connectionPhase = "Scanning…"
                case .failure(let failure):
                    self?.isScanning = false
                    self?.bluetoothError = failure.message
                }
            }
        }
    }

    func stopScan() {
        BluetoothManager.shared.stopScan { [weak self] _ in
            Task { @MainActor in
                self?.isScanning = false
                if self?.connectedDeviceName == nil {
                    self?.connectionPhase = "Not connected"
                }
            }
        }
    }

    func connect(to pair: DiscoveredGlassesPair) {
        bluetoothError = ""
        isScanning = false
        connectionPhase = "Connecting to \(pair.displayName)…"
        BluetoothManager.shared.connectToDevice(deviceName: pair.pairKey) { [weak self] result in
            Task { @MainActor in
                if case .failure(let failure) = result {
                    self?.bluetoothError = failure.message
                    self?.connectionPhase = "Connection failed"
                }
            }
        }
    }

    func disconnect() {
        BluetoothManager.shared.disconnectFromGlasses { [weak self] _ in
            Task { @MainActor in
                self?.connectedDeviceName = nil
                self?.connectionPhase = "Disconnected"
                self?.runtime.g1DeviceState.setConnection(left: false, right: false)
            }
        }
    }

    private func handleBleEvent(_ eventName: String, arguments: Any?) {
        switch eventName {
        case "foundPairedGlasses":
            guard let info = arguments as? [String: String],
                  let channel = info["channelNumber"] else { return }
            let pair = DiscoveredGlassesPair(
                channelNumber: channel,
                leftName: info["leftDeviceName"] ?? "",
                rightName: info["rightDeviceName"] ?? "",
                leftRssi: Int(info["leftRssi"] ?? "") ?? 0,
                rightRssi: Int(info["rightRssi"] ?? "") ?? 0
            )
            if let index = discoveredPairs.firstIndex(where: { $0.channelNumber == channel }) {
                discoveredPairs[index] = pair
            } else {
                discoveredPairs.append(pair)
            }

        case "glassesConnecting":
            let name = (arguments as? [String: String])?["deviceName"] ?? "glasses"
            connectionPhase = "Connecting to \(name)…"

        case "glassesConnected":
            guard let info = arguments as? [String: String] else { return }
            if info["partial"] == "true", let side = info["connectedSide"] {
                let left = side == "L" || runtime.g1DeviceState.leftLensConnected
                let right = side == "R" || runtime.g1DeviceState.rightLensConnected
                runtime.g1DeviceState.setConnection(left: left, right: right)
                connectionPhase = "Connected (\(side == "L" ? "left" : "right") lens)"
            } else {
                runtime.g1DeviceState.setConnection(left: true, right: true)
                connectionPhase = "Connected"
            }
            connectedDeviceName = [info["leftDeviceName"], info["rightDeviceName"]]
                .compactMap { $0 }
                .first { !$0.isEmpty }
            if runtime.g1DeviceState.leftLensConnected && runtime.g1DeviceState.rightLensConnected {
                startGlassesSession()
            }

        case "glassesDisconnected":
            runtime.g1DeviceState.setConnection(left: false, right: false)
            connectedDeviceName = nil
            let status = (arguments as? [String: Any])?["status"] as? String ?? "disconnected"
            connectionPhase = status == "poweredOff" ? "Bluetooth off" : "Disconnected"
            stopGlassesSession()

        case "bleWriteFailed":
            bluetoothError = "A BLE write failed; retrying on next page push."

        default:
            break
        }
    }

    private func handleInfoEvent(_ payload: [String: Any]) {
        let side: G1TouchpadSide = (payload["lr"] as? String) == "R" ? .right : .left
        let transportSide: G1Side = side == .right ? .right : .left

        if let data = payload["data"] as? Data {
            let bytes = Array(data)
            Task { await transport.handleInbound(bytes, from: transportSide) }

            if let status = statusDecoder.decode(bytes) {
                runtime.g1DeviceState.applyStatus(status)
                switch status {
                case .headUp:
                    handleHeadUp()
                case .caseState, .caseCharging, .caseBatteryPercent, .battery:
                    return  // pure status; not a touchpad press
                case .ack, .firmwareInfo:
                    return
                case .headDown:
                    break  // fall through so the touchpad router also sees it
                }
            }
        }

        guard let notifyIndex = payload["notifyIndex"] as? Int, notifyIndex >= 0 else { return }
        let action = runtime.g1DeviceState.handleTouchpad(notifyIndex: notifyIndex, side: side)
        switch action {
        case .previousPage, .nextPage:
            sendCurrentHudPage()
        default:
            break
        }
    }

    // MARK: - Glasses session lifecycle

    /// ACK-gated init sequence + periodic heartbeat/battery, mirroring the
    /// MentraOS reference driver. Runs when both lenses come up.
    private func startGlassesSession() {
        stopGlassesSession()
        let settings = runtime.settings

        heartbeatTask = Task { [weak self] in
            guard let self else { return }

            // Init handshake: 0x4D 0xFB expects 0xC9. Log and fall back to the
            // legacy 0x4D 0x01 if firmware doesn't ACK the new form.
            let initAcked = await self.transport.send(G1Command(
                bytes: self.commandEncoder.initHandshake(),
                ackPolicy: .required(command: 0x4D)
            ))
            NSLog("[G1DBG] init 0x4D 0xFB acked=\(initAcked)")
            if !initAcked {
                await self.transport.send(G1Command(bytes: [0x4D, 0x01]))
            }

            await self.transport.send(G1Command(bytes: self.commandEncoder.silentModeOff()))
            await self.transport.send(G1Command(bytes: self.commandEncoder.wearDetectionOff()))
            await self.transport.send(G1Command(
                bytes: self.commandEncoder.dateTimeSync(date: Date(), counter: self.nextPositionCounter())
            ))
            if let whitelist = try? self.commandEncoder.notificationWhitelist(
                appIdentifiers: [(id: Bundle.main.bundleIdentifier ?? "com.artjiang.helix", name: "Helix")]
            ) {
                for chunk in whitelist {
                    await self.transport.send(G1Command(bytes: chunk))
                }
            }
            await self.applyGlassesDisplaySettings(settings)

            // Periodic heartbeat (10 s) + battery poll (every 6th beat = 60 s).
            var beat = 0
            while !Task.isCancelled {
                await self.transport.send(G1Command(bytes: self.commandEncoder.heartbeat(counter: self.nextHeartbeatCounter())))
                if beat % 6 == 0 {
                    await self.transport.send(G1Command(bytes: self.commandEncoder.batteryPoll()))
                }
                beat += 1
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    private func stopGlassesSession() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        Task { await transport.reset() }
    }

    /// Sends the persisted brightness/angle/position config. Called on connect
    /// and whenever the user changes a glasses display setting.
    func applyGlassesDisplaySettings(_ settings: HelixSettings) async {
        await transport.send(G1Command(
            bytes: commandEncoder.brightness(level: settings.brightness, autoBrightness: settings.autoBrightness)
        ))
        await transport.send(G1Command(
            bytes: commandEncoder.headUpAngle(degrees: settings.headUpAngle)
        ))
        await transport.send(G1Command(
            bytes: commandEncoder.displayPosition(
                height: settings.displayHeight,
                depth: settings.displayDepth,
                counter: nextPositionCounter()
            ),
            ackPolicy: .required(command: 0x26)
        ))
    }

    private func handleHeadUp() {
        guard runtime.settings.dashboardEnabled else { return }
        // The firmware dashboard activates on head-up once datetime is synced;
        // re-sync opportunistically so the clock stays accurate.
        Task {
            await transport.send(G1Command(
                bytes: commandEncoder.dateTimeSync(date: Date(), counter: nextPositionCounter())
            ))
        }
    }

    private func nextHeartbeatCounter() -> UInt8 {
        heartbeatCounter &+= 1
        return heartbeatCounter
    }

    private func nextPositionCounter() -> UInt8 {
        positionCounter &+= 1
        return positionCounter
    }

    /// Forwards a Helix event to the glasses as a phone notification (0x4B).
    func forwardNotification(title: String, message: String) {
        guard isGlassesConnected, runtime.settings.glassesNotificationsEnabled else { return }
        notificationMessageID += 1
        guard let chunks = try? commandEncoder.notification(
            messageID: notificationMessageID,
            appIdentifier: Bundle.main.bundleIdentifier ?? "com.artjiang.helix",
            displayName: "Helix",
            title: title,
            message: message,
            date: Date()
        ) else { return }

        Task {
            guard await hudArbiter.requestDisplay(.notification, durationSeconds: 10) else { return }
            for chunk in chunks {
                await transport.send(G1Command(bytes: chunk))
            }
        }
    }

    // MARK: - HUD output

    private var wholeScreenSeq: UInt8 = 0

    /// Paginates `text` into the local HUD state and mirrors it to the
    /// glasses when connected. Single-page content uses the MentraOS-style
    /// whole-screen write (0x71 — the entire sentence lands at once);
    /// multi-page content keeps the paged path so touchpad paging works.
    func presentToGlasses(_ text: String, priority: HudArbiter.Priority = .answer) {
        runtime.g1DeviceState.presentText(text)
        if runtime.g1DeviceState.hudPages.count == 1 {
            sendWholeScreen(text, priority: priority)
        } else {
            sendCurrentHudPage(priority: priority)
        }
    }

    private func sendWholeScreen(_ text: String, priority: HudArbiter.Priority) {
        guard isGlassesConnected else { return }
        wholeScreenSeq &+= 1
        let packets = G1PacketEncoder().encodeWholeScreenText(text, seq: wholeScreenSeq)

        hudSendTask?.cancel()
        hudSendTask = Task {
            guard await hudArbiter.requestDisplay(priority) else { return }
            for (index, packet) in packets.enumerated() {
                guard !Task.isCancelled else { return }
                let isLastLeft = index == packets.count - 1
                await transport.send(G1Command(
                    bytes: packet,
                    sides: [.left],
                    postDelayNs: isLastLeft ? Self.interSideDelayNs : 8_000_000
                ))
            }
            guard !Task.isCancelled else { return }
            for packet in packets {
                guard !Task.isCancelled else { return }
                await transport.send(G1Command(bytes: packet, sides: [.right]))
            }
        }
    }

    private func sendCurrentHudPage(priority: HudArbiter.Priority = .answer) {
        guard isGlassesConnected else { return }
        let state = runtime.g1DeviceState
        guard state.hudPages.indices.contains(state.currentPageIndex) else { return }
        let packets = state.hudPages[state.currentPageIndex].packets

        hudSendTask?.cancel()
        hudSendTask = Task {
            guard await hudArbiter.requestDisplay(priority) else { return }
            // Left lens first, 400 ms settle, then right — all through the
            // serialized transport so heartbeats can't interleave (8 ms pacing
            // per chunk comes from G1Command's default postDelay).
            for (index, packet) in packets.enumerated() {
                guard !Task.isCancelled else { return }
                let isLastLeft = index == packets.count - 1
                await transport.send(G1Command(
                    bytes: packet,
                    sides: [.left],
                    postDelayNs: isLastLeft ? Self.interSideDelayNs : 8_000_000
                ))
            }
            guard !Task.isCancelled else { return }
            for packet in packets {
                guard !Task.isCancelled else { return }
                await transport.send(G1Command(bytes: packet, sides: [.right]))
            }
        }
    }

    // MARK: - Live listening

    func toggleListening() {
        if runtime.assistantSession.isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !runtime.assistantSession.isListening else { return }
        speechError = ""
        livePartialTranscript = ""

        SpeechStreamRecognizer.shared.attachEventHandler { [weak self] payload in
            Task { @MainActor in
                self?.handleSpeechEvent(payload)
            }
        }

        let useGlassesMic = isGlassesConnected
        Task {
            if useGlassesMic {
                // Open the glasses-side mic stream (0xF1 PCM frames follow).
                await transport.send(G1Command(bytes: commandEncoder.microphone(enabled: true)))
            }
            var backend = mappedTranscriptionBackend()
            var apiKey: String?
            if backend == .openai || backend == .whisper {
                apiKey = await runtime.apiKey(for: .openAI)
                if (apiKey ?? "").isEmpty {
                    backend = .appleCloud
                    apiKey = nil
                }
            }

            SpeechStreamRecognizer.shared.startRecognition(
                identifier: Locale.preferredLanguages.first ?? "en-US",
                source: useGlassesMic ? "glasses" : "microphone",
                backend: backend,
                apiKey: apiKey,
                model: runtime.settings.transcriptionModel
            ) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.runtime.assistantSession.setListening(true)
                        if useGlassesMic {
                            GlassesMicSessionManager.shared.startContinuousSession()
                        }
                    case .failure(let error):
                        self.speechError = error.localizedDescription
                    }
                }
            }
        }
    }

    func stopListening() {
        GlassesMicSessionManager.shared.stopContinuousSession()
        // The handler stays attached: stopRecognition(emitFinal:) delivers the
        // tail-end final asynchronously, and detaching here would drop it.
        SpeechStreamRecognizer.shared.stopRecognition(emitFinal: true)
        runtime.assistantSession.setListening(false)
        livePartialTranscript = ""
        if isGlassesConnected {
            Task {
                await transport.send(G1Command(bytes: commandEncoder.microphone(enabled: false)))
            }
        }
    }

    private func handleSpeechEvent(_ payload: [String: Any]) {
        if let message = payload["error"] as? String, !message.isEmpty {
            speechError = message
            return
        }
        guard let script = payload["script"] as? String else { return }
        let isFinal = payload["isFinal"] as? Bool ?? false

        if !isFinal {
            livePartialTranscript = script
            // Interim transcripts can also satisfy the sentence/interval
            // insight triggers (Merge behavior).
            Task { await runtime.insightCoordinator.handleTranscript(script, isFinal: false) }
            return
        }

        livePartialTranscript = ""
        liveTranscriptTask = Task { [previousTask = liveTranscriptTask] in
            await previousTask?.value
            let previousAnswer = runtime.assistantSession.currentAnswer
            let previousReminder = runtime.assistantSession.passiveReminder
            await runtime.assistantSession.processLiveTranscript(script)

            let answer = runtime.assistantSession.currentAnswer
            let engineAnswered = !answer.isEmpty && answer != previousAnswer
            if engineAnswered, isGlassesConnected {
                presentToGlasses(answer)
                forwardNotification(title: "Helix answered", message: answer)
            }

            let reminder = runtime.assistantSession.passiveReminder
            if !reminder.isEmpty, reminder != previousReminder {
                forwardNotification(title: "Fact check", message: reminder)
            }

            // Insights run after the engine turn so mutual exclusion can see
            // whether this utterance was already answered.
            await runtime.insightCoordinator.handleTranscript(
                script,
                isFinal: true,
                engineAnswered: engineAnswered
            )
        }
    }

    /// Maps the persisted HelixCore backend to the recognizer's local enum.
    /// Falls back to Apple Cloud when an OpenAI backend has no stored key.
    private func mappedTranscriptionBackend() -> TranscriptionBackend {
        switch runtime.settings.transcriptionBackend {
        case .appleOnDevice: return .appleOnDevice
        case .appleCloud: return .appleCloud
        case .openAIRealtime: return .openai
        case .openAITranscription: return .whisper
        }
    }
}

/// Backs the G1 transport with the app shell's CoreBluetooth manager.
struct BluetoothPacketWriter: G1PacketWriter {
    func write(_ bytes: [UInt8], to side: G1Side) async {
        let data = Data(bytes)
        let lr = side.rawValue
        await MainActor.run {
            BluetoothManager.shared.writeData(writeData: data, lr: lr)
        }
    }
}

/// Single owner of the glasses HUD. Multiple producers (answers,
/// notifications, dashboard, insights) request the display; higher priority
/// preempts lower, and expired windows free the display for anyone.
actor HudArbiter {
    enum Priority: Int, Comparable, Sendable {
        case insight = 0
        case dashboard = 1
        case notification = 2
        case answer = 3

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var activePriority: Priority?
    private var activeUntil: Date?

    /// Returns true when the caller may draw. Answers hold the display until
    /// replaced; timed producers pass a duration.
    func requestDisplay(_ priority: Priority, durationSeconds: TimeInterval? = nil) -> Bool {
        let now = Date()
        let activeExpired = activeUntil.map { $0 <= now } ?? (activePriority == nil)

        if let current = activePriority, !activeExpired, priority < current {
            return false
        }

        activePriority = priority
        activeUntil = durationSeconds.map { now.addingTimeInterval($0) }
        return true
    }

    func releaseDisplay() {
        activePriority = nil
        activeUntil = nil
    }
}
