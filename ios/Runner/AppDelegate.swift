import UIKit
import Flutter
import AVFoundation
import CoreBluetooth
import Speech
import NaturalLanguage

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var speechEventSink: FlutterEventSink?
    private var realtimeAudioEventSink: FlutterEventSink?
    private var bluetoothChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Audio session and microphone permissions are deferred until user starts recording

        // Clean up any Live Activities that survived a previous app crash/force-kill
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.cleanupStaleActivities()
        }

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = resolveFlutterViewController() else {
            assertionFailure("Failed to locate FlutterViewController during launch.")
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // Setup real Bluetooth manager
        let channel = FlutterMethodChannel(name: "method.bluetooth", binaryMessenger: controller.binaryMessenger)
        self.bluetoothChannel = channel

        registerLiveActivityButtonObservers()

        // Initialize BluetoothManager with the Flutter channel (like EvenDemoApp)
        let bluetoothManager = BluetoothManager.configure(channel: channel)
        
        // Set method call handler to delegate to real BluetoothManager
        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "startScan":
                bluetoothManager.startScan(result: result)
            case "stopScan":
                bluetoothManager.stopScan(result: result)
            case "connectToGlasses":
                if let args = call.arguments as? [String: Any], let deviceName = args["deviceName"] as? String {
                    bluetoothManager.connectToDevice(deviceName: deviceName, result: result)
                } else {
                    result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
                }
            case "disconnect", "disconnectFromGlasses":
                bluetoothManager.disconnectFromGlasses(result: result)
            case "send":
                if let params = call.arguments as? [String: Any] {
                    bluetoothManager.sendData(params: params)
                }
                result(nil)
            case "dartReady":
                bluetoothManager.onDartReady()
                result(nil)
            case "startEvenAI":
                let args = call.arguments as? [String: Any] ?? [:]
                let lang = args["language"] as? String ?? "EN"
                let source = args["source"] as? String ?? "glasses"
                let backendStr = args["backend"] as? String ?? "appleCloud"
                let sessionMode = args["sessionMode"] as? String ?? "transcription"
                let apiKey = args["apiKey"] as? String
                let model = args["model"] as? String
                let systemPrompt = args["systemPrompt"] as? String
                let voice = args["voice"] as? String ?? "alloy"
                let realtimeConversation =
                    sessionMode == "realtime" || backendStr == "openaiRealtime"

                let vadSensitivity = args["vadSensitivity"] as? Double ?? 0.5
                let transcriptionPrompt = args["transcriptionPrompt"] as? String ?? ""

                let enableDiarization = args["enableDiarization"] as? Bool ?? false
                let noiseReduction = args["noiseReduction"] as? Bool ?? false
                let chunkDurationSec = args["chunkDurationSec"] as? Double ?? 5.0

                let backend: TranscriptionBackend
                switch backendStr {
                case "openai", "openaiRealtime":
                    backend = .openai
                case "appleOnDevice":
                    backend = .appleOnDevice
                case "whisper":
                    backend = .whisper
                default:
                    backend = .appleCloud
                }

                // Configure Whisper-specific settings before starting
                let recognizer = SpeechStreamRecognizer.shared
                recognizer.enableDiarization = enableDiarization
                recognizer.noiseReductionEnabled = noiseReduction
                recognizer.whisperTranscriber.chunkDurationSec = chunkDurationSec

                recognizer.startRecognition(
                    identifier: lang,
                    source: source,
                    backend: backend,
                    apiKey: apiKey,
                    model: model,
                    realtimeConversation: realtimeConversation,
                    systemPrompt: systemPrompt,
                    voice: voice,
                    vadSensitivity: vadSensitivity,
                    transcriptionPrompt: transcriptionPrompt
                ) { startResult in
                    switch startResult {
                    case .success:
                        result("Started speech recognition (\(backendStr))")
                    case .failure(let error):
                        result(
                            FlutterError(
                                code: "SpeechStartFailed",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
            case "transcribeAudioFile":
                let args = call.arguments as? [String: Any] ?? [:]
                let filePath = args["filePath"] as? String ?? ""
                let lang = args["language"] as? String ?? "EN"
                let realtime = args["realtime"] as? Bool ?? false

                let fileURL = URL(fileURLWithPath: filePath)
                SpeechStreamRecognizer.shared.transcribeAudioFile(
                    fileURL: fileURL,
                    identifier: lang,
                    realtime: realtime
                ) { transcribeResult in
                    switch transcribeResult {
                    case .success:
                        result("Started file transcription: \(fileURL.lastPathComponent)")
                    case .failure(let error):
                        result(
                            FlutterError(
                                code: "TranscribeFileFailed",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
            case "stopEvenAI":
                let args = call.arguments as? [String: Any]
                let emitFinal = args?["emitFinal"] as? Bool ?? true
                SpeechStreamRecognizer.shared.stopRecognition(emitFinal: emitFinal)
                result("Stopped Even AI speech recognition")
            case "pauseEvenAI":
                SpeechStreamRecognizer.shared.pauseRecognition()
                result("Paused Even AI speech recognition")
            case "resumeEvenAI":
                SpeechStreamRecognizer.shared.resumeRecognition()
                result("Resumed Even AI speech recognition")
            case "sendDebugControl":
                if let params = call.arguments as? [String: Any],
                   let enable = params["enable"] as? Bool {
                    let data = Data([0x23, 0x6C, enable ? 0x00 : 0xC1])
                    bluetoothManager.writeData(writeData: data, lr: "L")
                    bluetoothManager.writeData(writeData: data, lr: "R")
                }
                result(nil)
            case "startLiveActivity":
                let args = call.arguments as? [String: Any]
                let mode = args?["mode"] as? String ?? "General"
                LiveActivityManager.shared.startActivity(mode: mode)
                result(nil)
            case "updateLiveActivity":
                let args = call.arguments as? [String: Any] ?? [:]
                // Note: `duration` is intentionally ignored — the widget
                // renders elapsed time locally off the immutable `startedAt`
                // attribute, so content-state updates no longer carry it.
                // See LiveActivityManager.updateActivity for rationale.
                LiveActivityManager.shared.updateActivity(
                    question: args["question"] as? String ?? "",
                    answer: args["answer"] as? String ?? "",
                    status: args["status"] as? String ?? "listening"
                )
                result(nil)
            case "stopLiveActivity":
                LiveActivityManager.shared.endActivity()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
     
        let scheduleEvent = FlutterEventChannel(name: "eventBleReceive", binaryMessenger: controller.binaryMessenger)
        scheduleEvent.setStreamHandler(self)
        
        let speechEvent = FlutterEventChannel(name: "eventSpeechRecognize", binaryMessenger: controller.binaryMessenger)
        speechEvent.setStreamHandler(self)

        let realtimeAudioEvent = FlutterEventChannel(name: "eventRealtimeAudio", binaryMessenger: controller.binaryMessenger)
        realtimeAudioEvent.setStreamHandler(self)

        // Wire up OpenAI Realtime audio output to the event channel
        SpeechStreamRecognizer.shared.onRealtimeAudioOutput = { [weak self] audioData in
            self?.realtimeAudioEventSink?(FlutterStandardTypedData(bytes: audioData))
        }
        SpeechStreamRecognizer.shared.onRealtimeAudioDone = { [weak self] in
            self?.realtimeAudioEventSink?(["event": "done"])
        }

        // NaturalLanguage channel (NLTagger NER, nouns, language detection)
        let nlChannel = FlutterMethodChannel(name: "method.naturalLanguage", binaryMessenger: controller.binaryMessenger)
        nlChannel.setMethodCallHandler { (call, result) in
            guard call.method == "analyzeText" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                result(["language": "", "entities": [], "nouns": []] as [String: Any])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                // 1. Language detection
                let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? ""

                // 2. Named Entity Recognition
                var entities: [[String: Any]] = []
                let nerTagger = NLTagger(tagSchemes: [.nameType])
                nerTagger.string = text
                let allowedTags: [NLTag] = [.personalName, .placeName, .organizationName]
                nerTagger.enumerateTags(
                    in: text.startIndex..<text.endIndex,
                    unit: .word,
                    scheme: .nameType,
                    options: [.omitWhitespace, .omitPunctuation, .joinNames]
                ) { tag, range in
                    if let tag = tag, allowedTags.contains(tag) {
                        let name = String(text[range])
                        let start = text.distance(from: text.startIndex, to: range.lowerBound)
                        let length = text.distance(from: range.lowerBound, to: range.upperBound)
                        let typeStr: String
                        switch tag {
                        case .personalName: typeStr = "PersonalName"
                        case .placeName: typeStr = "PlaceName"
                        case .organizationName: typeStr = "OrganizationName"
                        default: typeStr = tag.rawValue
                        }
                        entities.append([
                            "name": name,
                            "type": typeStr,
                            "start": start,
                            "length": length,
                        ])
                    }
                    return true
                }

                // 3. Noun extraction (deduplicated)
                var nouns: [String] = []
                var seenNouns = Set<String>()
                let lexTagger = NLTagger(tagSchemes: [.lexicalClass])
                lexTagger.string = text
                lexTagger.enumerateTags(
                    in: text.startIndex..<text.endIndex,
                    unit: .word,
                    scheme: .lexicalClass,
                    options: [.omitWhitespace, .omitPunctuation]
                ) { tag, range in
                    if tag == .noun {
                        let word = String(text[range]).lowercased()
                        if !seenNouns.contains(word) {
                            seenNouns.insert(word)
                            nouns.append(word)
                        }
                    }
                    return true
                }

                DispatchQueue.main.async {
                    result([
                        "language": language,
                        "entities": entities,
                        "nouns": nouns,
                    ] as [String: Any])
                }
            }
        }

        // EventKit channel (Calendar + Reminders)
        let eventKitChannel = FlutterMethodChannel(name: "method.eventkit", binaryMessenger: controller.binaryMessenger)
        eventKitChannel.setMethodCallHandler { (call, result) in
            EventKitChannel.shared.handle(call, result: result)
        }

        // HealthKit channel (Activity data for Enhanced HUD)
        let healthKitChannel = FlutterMethodChannel(name: "method.healthkit", binaryMessenger: controller.binaryMessenger)
        healthKitChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "getActivityData":
                HealthKitManager.shared.getActivityData { data in
                    result(data)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Passive Audio Monitor channels
        let passiveAudioChannel = FlutterMethodChannel(
            name: "method.passiveAudio",
            binaryMessenger: controller.binaryMessenger)
        passiveAudioChannel.setMethodCallHandler { (call, result) in
            let monitor = PassiveAudioMonitor.shared
            switch call.method {
            case "startPassiveListening":
                let args = call.arguments as? [String: Any] ?? [:]
                let language = args["language"] as? String ?? "en"
                let threshold = (args["vadThreshold"] as? NSNumber)?.floatValue ?? 0.01
                monitor.start(language: language, vadThreshold: threshold)
                result(nil)
            case "stopPassiveListening":
                monitor.stop()
                result(nil)
            case "pausePassiveListening":
                monitor.pause()
                result(nil)
            case "resumePassiveListening":
                monitor.resume()
                result(nil)
            case "getPassiveStatus":
                result([
                    "isActive": monitor.isActive,
                    "state": monitor.state.rawValue,
                    "segmentCount": monitor.segmentCount,
                ])
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let passiveEventChannel = FlutterEventChannel(
            name: "eventPassiveTranscription",
            binaryMessenger: controller.binaryMessenger)
        passiveEventChannel.setStreamHandler(PassiveAudioEventHandler())

        // WS-F: Input Inspector — dev-only capture of BT HID ring remote events
        InputInspectorController.shared.configure(host: controller)
        let inputInspectorChannel = FlutterMethodChannel(
            name: "method.input_inspector",
            binaryMessenger: controller.binaryMessenger)
        inputInspectorChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "startInspector":
                InputInspectorController.shared.startInspector()
                result(nil)
            case "stopInspector":
                InputInspectorController.shared.stopInspector()
                result(nil)
            case "startBackgroundListening":
                InputInspectorController.shared.startBackgroundListening()
                result(nil)
            case "stopBackgroundListening":
                InputInspectorController.shared.stopBackgroundListening()
                result(nil)
            case "getCapabilities":
                result(InputInspectorController.shared.capabilities())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        let inputInspectorEventChannel = FlutterEventChannel(
            name: "event.input_inspector",
            binaryMessenger: controller.binaryMessenger)
        inputInspectorEventChannel.setStreamHandler(InputInspectorStreamHandler.shared)

        let glassesMicHealthChannel = FlutterEventChannel(
            name: "eventGlassesMicHealth",
            binaryMessenger: controller.binaryMessenger)
        glassesMicHealthChannel.setStreamHandler(GlassesMicHealthEventHandler())

        // Audio session is configured when recording starts (Flutter/SpeechRecognizer handles it)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func registerLiveActivityButtonObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CFNotificationCallback = { _, observer, name, _, _ in
            guard let observer = observer, let name = name else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
            let raw = name.rawValue as String
            DispatchQueue.main.async {
                delegate.forwardLiveActivityButton(rawName: raw)
            }
        }
        for button in [
            HelixLiveActivityIntentBridge.Button.askQuestion,
            .pauseTranscription,
            .resumeTranscription,
        ] {
            CFNotificationCenterAddObserver(
                center,
                observer,
                callback,
                button.rawValue as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    private func forwardLiveActivityButton(rawName: String) {
        guard let button = HelixLiveActivityIntentBridge.Button(rawValue: rawName) else { return }
        let id: String
        switch button {
        case .askQuestion:         id = "askQuestion"
        case .pauseTranscription:  id = "pauseTranscription"
        case .resumeTranscription: id = "resumeTranscription"
        }
        bluetoothChannel?.invokeMethod(
            "liveActivityButtonPressed",
            arguments: ["button": id]
        )
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        super.applicationWillTerminate(application)
    }

    private func resolveFlutterViewController() -> FlutterViewController? {
        if let controller = window?.rootViewController as? FlutterViewController {
            return controller
        }

        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        for scene in activeScenes {
            if let controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController as? FlutterViewController {
                return controller
            }
            if let controller = scene.windows.first?.rootViewController as? FlutterViewController {
                return controller
            }
        }

        return nil
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate : FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if (arguments as? String == "eventBleReceive") {
            BluetoothManager.shared.blueInfoSink = events
        } else if (arguments as? String == "eventSpeechRecognize") {
            speechEventSink = events
            SpeechStreamRecognizer.shared.attachEventSink(events)
        } else if (arguments as? String == "eventRealtimeAudio") {
            realtimeAudioEventSink = events
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if (arguments as? String == "eventBleReceive") {
            BluetoothManager.shared.blueInfoSink = nil
        } else if (arguments as? String == "eventSpeechRecognize") {
            speechEventSink = nil
            SpeechStreamRecognizer.shared.detachEventSink()
        } else if (arguments as? String == "eventRealtimeAudio") {
            realtimeAudioEventSink = nil
        }
        return nil
    }
}
