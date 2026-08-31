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

/// One accepted HUD request for all answers produced by a single ordered live
/// transcript outcome. Keeping the answer count with the payload lets the UI
/// mark every corresponding bubble as requested without pretending that a
/// later send superseded an earlier answer.
struct LiveTranscriptHUDRequest: Equatable {
    let sequence: UInt64
    let answerCount: Int
    let text: String
}

enum G1HUDDeliveryResult: Equatable {
    case deliveredToBothLenses
    case deliveredToLeftLens
    case deliveredToRightLens
    case failed
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

    /// Fires once per committed transcript outcome immediately before its
    /// answer(s) are requested on the glasses HUD. This is request truth, not
    /// a device delivery acknowledgement.
    var onLiveTranscriptHUDSendRequested: ((UInt64) -> Void)?
    var onLiveTranscriptHUDDeliveryResult: ((UInt64, G1HUDDeliveryResult) -> Void)?

    /// In-flight HUD page push; cancelled when a newer page supersedes it so
    /// packets from two pages never interleave on the glasses.
    private var hudSendTask: Task<Void, Never>?
    private var hudResetTask: Task<Void, Never>?
    private var activeHUDDeliveryObserver: ((G1HUDDeliveryResult) -> Void)?
    private var presentationEpoch: UInt64 = 0

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

    init(
        runtime: HelixRuntimeDependencies,
        transport: G1CommandTransport? = nil
    ) {
        self.runtime = runtime
        self.transport = transport ?? G1CommandTransport(writer: BluetoothPacketWriter())
    }

    static func makeLiveTranscriptHUDRequest(
        sequence: UInt64,
        answers: [String]
    ) -> LiveTranscriptHUDRequest? {
        let acceptedAnswers = answers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !acceptedAnswers.isEmpty else { return nil }
        return LiveTranscriptHUDRequest(
            sequence: sequence,
            answerCount: acceptedAnswers.count,
            text: acceptedAnswers.joined(separator: "\n\n")
        )
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
        runtime.assistantSession.addLiveTranscriptCommitHandler { [weak self] outcome in
            self?.handleCommittedLiveTranscript(outcome)
        }
        runtime.insightCoordinator.onDisplay = { [weak self] insight in
            guard let self, self.isGlassesConnected else { return }
            let epoch = self.presentationEpoch
            Task {
                guard await self.isPresentationCurrent(epoch) else { return }
                guard await self.hudArbiter.requestDisplay(.insight, durationSeconds: 10) else { return }
                guard await self.isPresentationCurrent(epoch) else { return }
                self.activeHUDDeliveryObserver = nil
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

    func handleBleEvent(_ eventName: String, arguments: Any?) {
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
            hudSendTask?.cancel()
            hudSendTask = nil
            if isGlassesConnected {
                startGlassesSession()
            }

        case "glassesDisconnected":
            hudSendTask?.cancel()
            hudSendTask = nil
            let info = arguments as? [String: Any]
            let status = info?["status"] as? String ?? "disconnected"
            if status != "poweredOff",
               let disconnectedSide = info?["disconnectedSide"] as? String,
               ["L", "R"].contains(disconnectedSide) {
                let left = disconnectedSide == "L" ? false : runtime.g1DeviceState.leftLensConnected
                let right = disconnectedSide == "R" ? false : runtime.g1DeviceState.rightLensConnected
                runtime.g1DeviceState.setConnection(left: left, right: right)
                if isGlassesConnected {
                    connectionPhase = left ? "Connected (left lens)" : "Connected (right lens)"
                    startGlassesSession()
                } else {
                    connectedDeviceName = nil
                    connectionPhase = "Disconnected"
                    stopGlassesSession()
                }
            } else {
                runtime.g1DeviceState.setConnection(left: false, right: false)
                connectedDeviceName = nil
                connectionPhase = status == "poweredOff" ? "Bluetooth off" : "Disconnected"
                stopGlassesSession()
            }

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
        handleTouchpad(notifyIndex: notifyIndex, side: side)
    }

    private func handleTouchpad(notifyIndex: Int, side: G1TouchpadSide) {
        let action = runtime.g1DeviceState.handleTouchpad(notifyIndex: notifyIndex, side: side)
        switch action {
        case .previousPage, .nextPage:
            sendCurrentHudPage(completion: activeHUDDeliveryObserver)
        default:
            break
        }
    }

    func handleTouchpadForTesting(notifyIndex: Int, side: G1TouchpadSide) {
        handleTouchpad(notifyIndex: notifyIndex, side: side)
    }

    // MARK: - Glasses session lifecycle

    /// ACK-gated init sequence + periodic heartbeat/battery, mirroring the
    /// MentraOS reference driver. Runs for whichever lens links are ready.
    private func startGlassesSession() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        let settings = runtime.settings

        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            // Serialize reset before the replacement session begins; a detached
            // reset from the prior lens set could otherwise cancel this new
            // session's first ACK waiter.
            await self.transport.reset()
            let sides = self.connectedLensSides
            guard !sides.isEmpty else { return }

            // Init handshake: 0x4D 0xFB expects 0xC9. Log and fall back to the
            // legacy 0x4D 0x01 if firmware doesn't ACK the new form.
            let initAcked = await self.transport.send(G1Command(
                bytes: self.commandEncoder.initHandshake(),
                sides: sides,
                ackPolicy: .required(command: 0x4D)
            ))
            NSLog("[G1DBG] init 0x4D 0xFB acked=\(initAcked)")
            if !initAcked {
                await self.transport.send(G1Command(bytes: [0x4D, 0x01], sides: sides))
            }

            await self.transport.send(G1Command(bytes: self.commandEncoder.silentModeOff(), sides: sides))
            await self.transport.send(G1Command(bytes: self.commandEncoder.wearDetectionOff(), sides: sides))
            await self.transport.send(G1Command(
                bytes: self.commandEncoder.dateTimeSync(date: Date(), counter: self.nextPositionCounter()),
                sides: sides
            ))
            if let whitelist = try? self.commandEncoder.notificationWhitelist(
                appIdentifiers: [(id: Bundle.main.bundleIdentifier ?? "com.artjiang.helix", name: "Helix")]
            ), self.runtime.g1DeviceState.leftLensConnected {
                for chunk in whitelist {
                    let acknowledged = await self.transport.send(G1Command(
                        bytes: chunk,
                        sides: [.left],
                        ackPolicy: .required(command: 0x04)
                    ))
                    guard acknowledged else { break }
                }
            }
            await self.applyGlassesDisplaySettings(settings)

            // Periodic heartbeat (10 s) + battery poll (every 6th beat = 60 s).
            var beat = 0
            while !Task.isCancelled {
                await self.transport.send(G1Command(
                    bytes: self.commandEncoder.heartbeat(counter: self.nextHeartbeatCounter()),
                    sides: sides
                ))
                if beat % 6 == 0 {
                    await self.transport.send(G1Command(bytes: self.commandEncoder.batteryPoll(), sides: sides))
                }
                beat += 1
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    private func stopGlassesSession() {
        hudSendTask?.cancel()
        hudSendTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        Task { await transport.reset() }
    }

    /// Sends the persisted brightness/angle/position config. Called on connect
    /// and whenever the user changes a glasses display setting.
    func applyGlassesDisplaySettings(_ settings: HelixSettings) async {
        let sides = connectedLensSides
        guard !sides.isEmpty else { return }
        await transport.send(G1Command(
            bytes: commandEncoder.brightness(level: settings.brightness, autoBrightness: settings.autoBrightness),
            sides: sides
        ))
        await transport.send(G1Command(
            bytes: commandEncoder.headUpAngle(degrees: settings.headUpAngle),
            sides: sides
        ))
        let previewAcknowledged = await transport.send(G1Command(
            bytes: commandEncoder.displayPosition(
                height: settings.displayHeight,
                depth: settings.displayDepth,
                counter: nextPositionCounter(),
                preview: true
            ),
            sides: sides,
            ackPolicy: .required(command: 0x26)
        ))
        if previewAcknowledged {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
        await transport.send(G1Command(
            bytes: commandEncoder.displayPosition(
                height: settings.displayHeight,
                depth: settings.displayDepth,
                counter: nextPositionCounter(),
                preview: false
            ),
            sides: sides,
            ackPolicy: .required(command: 0x26)
        ))
    }

    private func handleHeadUp() {
        guard runtime.settings.dashboardEnabled else { return }
        // The firmware dashboard activates on head-up once datetime is synced;
        // re-sync opportunistically so the clock stays accurate.
        Task {
            await transport.send(G1Command(
                bytes: commandEncoder.dateTimeSync(date: Date(), counter: nextPositionCounter()),
                sides: connectedLensSides
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
        guard runtime.g1DeviceState.leftLensConnected,
              runtime.settings.glassesNotificationsEnabled else { return }
        notificationMessageID += 1
        guard let chunks = try? commandEncoder.notification(
            messageID: notificationMessageID,
            appIdentifier: Bundle.main.bundleIdentifier ?? "com.artjiang.helix",
            displayName: "Helix",
            title: title,
            message: message,
            date: Date()
        ) else { return }
        let epoch = presentationEpoch

        Task {
            guard await self.isPresentationCurrent(epoch) else { return }
            guard await hudArbiter.requestDisplay(.notification, durationSeconds: 10) else { return }
            for chunk in chunks {
                guard await self.isPresentationCurrent(epoch) else { return }
                let acknowledged = await transport.send(G1Command(
                    bytes: chunk,
                    sides: [.left],
                    ackPolicy: .required(command: 0x4B),
                    maxAttempts: 6
                ))
                guard acknowledged else { return }
            }
        }
    }

    // MARK: - HUD output

    private var wholeScreenSeq: UInt8 = 0

    /// Paginates `text` into the local HUD state and mirrors it to the
    /// glasses when connected. Single-page content uses the MentraOS-style
    /// whole-screen write (0x71 — the entire sentence lands at once);
    /// multi-page content keeps the paged path so touchpad paging works.
    func presentToGlasses(
        _ text: String,
        priority: HudArbiter.Priority = .answer,
        completion: ((G1HUDDeliveryResult) -> Void)? = nil
    ) {
        activeHUDDeliveryObserver = completion
        runtime.g1DeviceState.presentText(text)
        if runtime.g1DeviceState.hudPages.count == 1 {
            sendWholeScreen(text, priority: priority, completion: completion)
        } else {
            sendCurrentHudPage(priority: priority, completion: completion)
        }
    }

    private func sendWholeScreen(
        _ text: String,
        priority: HudArbiter.Priority,
        completion: ((G1HUDDeliveryResult) -> Void)? = nil
    ) {
        let sides = connectedLensSides
        guard !sides.isEmpty else {
            completion?(.failed)
            return
        }
        let epoch = presentationEpoch
        wholeScreenSeq &+= 1
        let packets = G1PacketEncoder().encodeWholeScreenText(text, seq: wholeScreenSeq)

        hudSendTask?.cancel()
        hudSendTask = Task {
            var reportedResult = false
            defer {
                if !reportedResult { completion?(.failed) }
            }
            guard await self.isPresentationCurrent(epoch) else { return }
            guard await hudArbiter.requestDisplay(priority) else { return }
            let result = await self.sendHUDPackets(packets, to: sides, epoch: epoch)
            reportedResult = true
            completion?(result)
        }
    }

    private func sendCurrentHudPage(
        priority: HudArbiter.Priority = .answer,
        completion: ((G1HUDDeliveryResult) -> Void)? = nil
    ) {
        let sides = connectedLensSides
        guard !sides.isEmpty else {
            completion?(.failed)
            return
        }
        let epoch = presentationEpoch
        let state = runtime.g1DeviceState
        guard state.hudPages.indices.contains(state.currentPageIndex) else { return }
        let page = state.hudPages[state.currentPageIndex]
        wholeScreenSeq &+= 1
        let packets = G1PacketEncoder().encodeTextPage(
            page.text,
            syncSequence: wholeScreenSeq,
            currentPage: UInt8(clamping: page.pageNumber),
            maxPage: UInt8(clamping: page.pageCount)
        )

        hudSendTask?.cancel()
        hudSendTask = Task {
            var reportedResult = false
            defer {
                if !reportedResult { completion?(.failed) }
            }
            guard await self.isPresentationCurrent(epoch) else { return }
            guard await hudArbiter.requestDisplay(priority) else { return }
            let result = await self.sendHUDPackets(packets, to: sides, epoch: epoch)
            reportedResult = true
            completion?(result)
        }
    }

    /// Direct-text screens are ACK-gated packet-by-packet. A complete left
    /// lens transfer is required before the first right-lens packet is written.
    private func sendHUDPackets(
        _ packets: [[UInt8]],
        to sides: [G1Side],
        epoch: UInt64
    ) async -> G1HUDDeliveryResult {
        guard !Task.isCancelled,
              await isPresentationCurrent(epoch) else { return .failed }
        let commands = sides.flatMap { side in
            packets.map { packet in
                G1Command(
                    bytes: packet,
                    sides: [side],
                    ackPolicy: .required(command: G1PacketEncoder.commandByte)
                )
            }
        }
        let results = await transport.sendBatch(commands)
        var deliveredSides: [G1Side] = []
        var resultOffset = 0
        for side in sides {
            let resultEnd = resultOffset + packets.count
            guard results.count >= resultEnd,
                  results[resultOffset..<resultEnd].allSatisfy({ $0 }) else {
                break
            }
            deliveredSides.append(side)
            resultOffset = resultEnd
        }
        return deliveryResult(for: deliveredSides)
    }

    private var connectedLensSides: [G1Side] {
        var sides: [G1Side] = []
        if runtime.g1DeviceState.leftLensConnected { sides.append(.left) }
        if runtime.g1DeviceState.rightLensConnected { sides.append(.right) }
        return sides
    }

    private func deliveryResult(for sides: [G1Side]) -> G1HUDDeliveryResult {
        let delivered = Set(sides)
        if delivered == Set(G1Side.allCases) { return .deliveredToBothLenses }
        if delivered == Set([.left]) { return .deliveredToLeftLens }
        if delivered == Set([.right]) { return .deliveredToRightLens }
        return .failed
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
        Task { [weak self] in
            guard let self else { return }
            if useGlassesMic {
                // Open the glasses-side mic stream (0xF1 PCM frames follow).
                await self.transport.send(
                    G1Command(bytes: self.commandEncoder.microphone(enabled: true))
                )
            }
            var backend = self.mappedTranscriptionBackend()
            var apiKey: String?
            if backend == .openai || backend == .whisper {
                apiKey = await self.runtime.apiKey(for: .openAI)
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
                model: self.runtime.settings.transcriptionModel
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

    /// Cancels the current recognizer generation without flushing its tail.
    /// Use before clearing conversation state so a late provider callback from
    /// the old session cannot repopulate the new conversation.
    func stopListeningForNewConversation() {
        GlassesMicSessionManager.shared.stopContinuousSession()
        SpeechStreamRecognizer.shared.stopRecognition(emitFinal: false)
        SpeechStreamRecognizer.shared.detachEventHandler()
        runtime.assistantSession.setListening(false)
        runtime.insightCoordinator.resetConversation()
        livePartialTranscript = ""
        // Conversation reset is also a privacy boundary for the HUD. Stop any
        // old page stream before clearing both local presentation truth and the
        // physical firmware screen.
        hudSendTask?.cancel()
        hudSendTask = nil
        activeHUDDeliveryObserver = nil
        presentationEpoch &+= 1
        let resetEpoch = presentationEpoch
        let previousReset = hudResetTask
        runtime.g1DeviceState.clearHud()
        let shouldClearPhysicalHUD = isGlassesConnected
        hudResetTask = Task {
            await previousReset?.value
            await hudArbiter.releaseDisplay()
            guard resetEpoch == presentationEpoch else { return }
            if shouldClearPhysicalHUD {
                await transport.send(G1Command(bytes: commandEncoder.microphone(enabled: false)))
                for side in connectedLensSides {
                    let acknowledged = await transport.send(G1Command(
                        bytes: commandEncoder.exitAllFunctions(),
                        sides: [side],
                        ackPolicy: .required(command: 0x18)
                    ))
                    guard acknowledged else { break }
                }
            }
        }
    }

    /// Presentation tasks from a prior conversation wait behind the reset and
    /// then fail the epoch check. New-session tasks wait until the physical
    /// clear command is durably ordered ahead of them.
    private func isPresentationCurrent(_ epoch: UInt64) async -> Bool {
        await hudResetTask?.value
        return epoch == presentationEpoch
    }

    func waitForPresentationResetForTesting() async {
        await hudResetTask?.value
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
        // Each finalized segment starts immediately. NativeAssistantSessionState
        // buffers completed outcomes and invokes the commit handler in transcript
        // arrival order, so a slow provider never blocks a later provider request
        // and neither valid answer task is cancelled.
        let sourceSegmentID: String?
        if let stringID = payload["segmentId"] as? String {
            sourceSegmentID = stringID
        } else if let numericID = payload["segmentId"] as? NSNumber {
            sourceSegmentID = numericID.stringValue
        } else {
            sourceSegmentID = nil
        }
        let speaker = payload["speaker"] as? String
        let speakerSource = (payload["speakerSource"] as? String)
            .flatMap(TranscriptSpeakerSource.init(rawValue:))
            ?? (speaker == nil ? nil : .sourceProvided)
        let speakerConfidence = (payload["speakerConfidence"] as? NSNumber)?.doubleValue
        Task {
            await runtime.assistantSession.processLiveTranscript(
                script,
                sourceSegmentID: sourceSegmentID,
                speaker: speaker,
                speakerSource: speakerSource,
                speakerConfidence: speakerConfidence
            )
        }
    }

    private func handleCommittedLiveTranscript(_ outcome: NativeLiveTranscriptOutcome) {
        guard let turn = outcome.turn else { return }

        let resultAnswers = turn.questionResults.compactMap(\.answer?.text)
        let answers = resultAnswers.isEmpty ? turn.answer.map { [$0.text] } ?? [] : resultAnswers
        if isGlassesConnected,
           let request = Self.makeLiveTranscriptHUDRequest(
               sequence: outcome.sequence,
               answers: answers
           ) {
            // Accept one complete payload before exposing request state. Two
            // synchronous presentToGlasses calls would cancel the first HUD
            // task, despite both answer bubbles appearing requested in the UI.
            onLiveTranscriptHUDSendRequested?(request.sequence)
            presentToGlasses(request.text) { [weak self] result in
                self?.onLiveTranscriptHUDDeliveryResult?(request.sequence, result)
            }
        }
        for answer in answers where isGlassesConnected {
            forwardNotification(title: "Helix answered", message: answer)
        }

        if let reminder = turn.passiveReminder?.reminder, !reminder.isEmpty {
            forwardNotification(title: "Fact check", message: reminder)
        }

        // Insights run after the ordered engine commit so mutual exclusion can
        // see whether this utterance was already answered.
        Task {
            await runtime.insightCoordinator.handleTranscript(
                outcome.segment.text,
                isFinal: true,
                engineAnswered: outcome.answered
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
