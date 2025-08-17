// ABOUTME: iOS application delegate integrating Flutter and initializing basic audio session checks.
// ABOUTME: Compiles only when UIKit is available; excluded on macOS to avoid availability issues.
#if canImport(UIKit)
import UIKit
import Flutter
import AVFoundation

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
#endif
