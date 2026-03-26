import UIKit
import Flutter
import AVFoundation
import CoreBluetooth
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var speechEventSink: FlutterEventSink?
    private var realtimeAudioEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Audio session and microphone permissions are deferred until user starts recording
        
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = resolveFlutterViewController() else {
            assertionFailure("Failed to locate FlutterViewController during launch.")
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // Setup real Bluetooth manager
        let channel = FlutterMethodChannel(name: "method.bluetooth", binaryMessenger: controller.binaryMessenger)
        
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
                    voice: voice
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
            case "startLiveActivity":
                if #available(iOS 16.2, *) {
                    let args = call.arguments as? [String: Any]
                    let mode = args?["mode"] as? String ?? "General"
                    LiveActivityManager.shared.startActivity(mode: mode)
                }
                result(nil)
            case "updateLiveActivity":
                if #available(iOS 16.2, *) {
                    let args = call.arguments as? [String: Any] ?? [:]
                    LiveActivityManager.shared.updateActivity(
                        question: args["question"] as? String ?? "",
                        answer: args["answer"] as? String ?? "",
                        status: args["status"] as? String ?? "listening",
                        duration: args["duration"] as? Int ?? 0
                    )
                }
                result(nil)
            case "stopLiveActivity":
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.endActivity()
                }
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

        // EventKit channel (Calendar + Reminders)
        let eventKitChannel = FlutterMethodChannel(name: "method.eventkit", binaryMessenger: controller.binaryMessenger)
        eventKitChannel.setMethodCallHandler { (call, result) in
            EventKitChannel.shared.handle(call, result: result)
        }

        // Audio session is configured when recording starts (Flutter/SpeechRecognizer handles it)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
