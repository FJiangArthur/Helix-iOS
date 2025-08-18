import UIKit
import Flutter
import AVFoundation
import CoreBluetooth
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var speechEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Enable basic audio debugging
        print("🎤 App starting - checking audio permissions")
        
        // Log current audio session state (Flutter's audio_session will configure it)
        let session = AVAudioSession.sharedInstance()
        print("🎤 Initial Audio Session Category: \(session.category.rawValue)")
        
        // Add observer to detect category changes for debugging
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, 
                                             object: nil, 
                                             queue: .main) { _ in
          print("🔄 Audio route changed - Category: \(session.category.rawValue)")
        }
        
        // Request microphone permission early
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          print("🎤 Microphone permission request result: \(granted)")
        }
        
        // Log audio session state AFTER configuration
        print("🎤 Audio Session Category: \(session.category.rawValue)")
        print("🎤 Recording Permission: \(session.recordPermission.rawValue)")
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup real Bluetooth manager
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "method.bluetooth", binaryMessenger: controller.binaryMessenger)
        
        // Initialize BluetoothManager with the Flutter channel
        let bluetoothManager = BluetoothManager.shared
        bluetoothManager.channel = channel
        
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
            case "disconnectFromGlasses":
                bluetoothManager.disconnectFromGlasses(result: result)
            case "send":
                if let params = call.arguments as? [String: Any] {
                    bluetoothManager.sendData(params: params)
                }
                result(nil)
            case "startEvenAI":
                SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")
                result("Started Even AI speech recognition")
            case "stopEvenAI":
                SpeechStreamRecognizer.shared.stopRecognition()
                result("Stopped Even AI speech recognition")
            default:
                result(FlutterMethodNotImplemented)
            }
        }
     
        let scheduleEvent = FlutterEventChannel(name: "eventBleReceive", binaryMessenger: controller.binaryMessenger)
        scheduleEvent.setStreamHandler(self)
        
        let speechEvent = FlutterEventChannel(name: "eventSpeechRecognize", binaryMessenger: controller.binaryMessenger)
        speechEvent.setStreamHandler(self)
        
        // Basic audio session setup - flutter_sound and audio_session will handle the rest
        do {
          try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
          print("✅ Basic audio session category set to playAndRecord")
        } catch {
          print("⚠️ Failed to set basic audio category: \(error)")
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate : FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if (arguments as? String == "eventBleReceive") {
            BluetoothManager.shared.blueInfoSink = events
        } else if (arguments as? String == "eventSpeechRecognize") {
            BluetoothManager.shared.blueSpeechSink = events
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
