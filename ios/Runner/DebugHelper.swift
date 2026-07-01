// ABOUTME: Utility for logging and validating AVAudioSession configuration during development.
// ABOUTME: iOS-only implementation guarded by UIKit; provides no-op stubs on other platforms.
#if canImport(UIKit)
import Foundation
import AVFoundation

@objc class DebugHelper: NSObject {
    
    @objc static func setupAudioDebugLogging() {
        // Enable AVAudioSession debugging
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Log current audio session state
        let session = AVAudioSession.sharedInstance()
        print("🎤 Audio Session Category: \(session.category.rawValue)")
        print("🎤 Audio Session Mode: \(session.mode.rawValue)")
        print("🎤 Sample Rate: \(session.sampleRate)")
        print("🎤 Input Available: \(session.isInputAvailable)")
        print("🎤 Input Channels: \(session.inputNumberOfChannels)")
        let recordPermission: Any
        if #available(iOS 17.0, *) {
            recordPermission = AVAudioApplication.shared.recordPermission
        } else {
            recordPermission = AVAudioSession.sharedInstance().recordPermission
        }
        print("🎤 Recording Permission: \(recordPermission)")

        // Check microphone permission
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                print("✅ Microphone permission granted")
            case .denied:
                print("❌ Microphone permission denied")
            case .undetermined:
                print("⚠️ Microphone permission undetermined")
            @unknown default:
                print("❓ Unknown microphone permission state")
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                print("✅ Microphone permission granted")
            case .denied:
                print("❌ Microphone permission denied")
            case .undetermined:
                print("⚠️ Microphone permission undetermined")
            @unknown default:
                print("❓ Unknown microphone permission state")
            }
        }
    }
    
    @objc static func handleRouteChange(_ notification: Notification) {
        print("🔄 Audio route changed: \(notification)")
    }
    
    @objc static func handleInterruption(_ notification: Notification) {
        print("⚠️ Audio interruption: \(notification)")
    }
    
    @objc static func checkAudioSetup() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Try to set up the audio session for recording
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            print("✅ Audio session setup successful")
            print("🎤 Input gain: \(session.inputGain)")
            print("🎤 Input latency: \(session.inputLatency)")
            print("🎤 Output latency: \(session.outputLatency)")
            
            return true
        } catch {
            print("❌ Audio session setup failed: \(error)")
            return false
        }
    }
}
#else
import Foundation

@objc class DebugHelper: NSObject {
    @objc static func setupAudioDebugLogging() {
        print("ℹ️ DebugHelper.setupAudioDebugLogging is a no-op on this platform")
    }
    
    @objc static func handleRouteChange(_ notification: Notification) {
        print("ℹ️ DebugHelper.handleRouteChange is a no-op on this platform")
    }
    
    @objc static func handleInterruption(_ notification: Notification) {
        print("ℹ️ DebugHelper.handleInterruption is a no-op on this platform")
    }
    
    @objc static func checkAudioSetup() -> Bool {
        print("ℹ️ DebugHelper.checkAudioSetup is a no-op on this platform")
        return false
    }
}
#endif
