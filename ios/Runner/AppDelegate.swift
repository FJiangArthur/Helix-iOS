import UIKit
import Flutter
import AVFoundation
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {

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
        
        // Setup G1 Bluetooth method channel with mock responses for development  
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "method.bluetooth", binaryMessenger: controller.binaryMessenger)
        
        // Set method call handler for Flutter channel with development responses
        channel.setMethodCallHandler { (call, result) in
            print("AppDelegate----call----\(call)----\(call.method)---------")
            
            // Mock responses for development - replace with real BluetoothManager later
            switch call.method {
            case "startScan":
                result("Mock: Started scanning for glasses...")
            case "stopScan":
                result("Mock: Stopped scanning")
            case "connectToGlasses":
                if let args = call.arguments as? [String: Any], let deviceName = args["deviceName"] as? String {
                    result("Mock: Connected to \(deviceName)")
                } else {
                    result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
                }
            case "disconnectFromGlasses":
                result("Mock: Disconnected from glasses")
            case "send":
                result(nil)
            case "startEvenAI":
                // TODO: Implement speech recognition
                result("Mock: Started Even AI")
            case "stopEvenAI":
                // TODO: Implement speech recognition
                result("Mock: Stopped Even AI")
            default:
                result(FlutterMethodNotImplemented)
            }
        }
     
        let scheduleEvent = FlutterEventChannel(name: "eventBleReceive", binaryMessenger: controller.binaryMessenger)
        scheduleEvent.setStreamHandler(self)
        
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
        // Mock BLE event streaming for development
       if (arguments as? String == "eventBleStatus"){
            // TODO: Implement BLE status events
        } else if (arguments as? String == "eventBleReceive") {
            // TODO: Implement BLE data events  
        } else {
            // TODO: Handle other event types
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}