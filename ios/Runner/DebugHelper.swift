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
        HelixLogger.audio("Audio Session Category: \(session.category.rawValue)", level: .debug, metadata: [
            "mode": session.mode.rawValue,
            "sampleRate": "\(session.sampleRate)",
            "inputAvailable": "\(session.isInputAvailable)",
            "inputChannels": "\(session.inputNumberOfChannels)"
        ])

        // Check microphone permission
        let permission = AVAudioSession.sharedInstance().recordPermission
        switch permission {
        case .granted:
            HelixLogger.audio("Microphone permission granted", level: .info)
        case .denied:
            HelixLogger.audio("Microphone permission denied", level: .error)
        case .undetermined:
            HelixLogger.audio("Microphone permission undetermined", level: .warning)
        @unknown default:
            HelixLogger.audio("Unknown microphone permission state", level: .warning)
        }
    }

    @objc static func handleRouteChange(_ notification: Notification) {
        HelixLogger.audio("Audio route changed", level: .info, metadata: [
            "notification": "\(notification.name)"
        ])
    }

    @objc static func handleInterruption(_ notification: Notification) {
        HelixLogger.audio("Audio interruption occurred", level: .warning, metadata: [
            "notification": "\(notification.name)"
        ])
    }

    @objc static func checkAudioSetup() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()

            // Try to set up the audio session for recording
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            HelixLogger.audio("Audio session setup successful", level: .info, metadata: [
                "inputGain": "\(session.inputGain)",
                "inputLatency": "\(session.inputLatency)",
                "outputLatency": "\(session.outputLatency)"
            ])

            return true
        } catch {
            HelixLogger.error("Audio session setup failed", error: error, category: .audio)
            return false
        }
    }
}
#else
import Foundation

@objc class DebugHelper: NSObject {
    @objc static func setupAudioDebugLogging() {
        HelixLogger.info("DebugHelper.setupAudioDebugLogging is a no-op on this platform", category: .audio)
    }

    @objc static func handleRouteChange(_ notification: Notification) {
        HelixLogger.info("DebugHelper.handleRouteChange is a no-op on this platform", category: .audio)
    }

    @objc static func handleInterruption(_ notification: Notification) {
        HelixLogger.info("DebugHelper.handleInterruption is a no-op on this platform", category: .audio)
    }

    @objc static func checkAudioSetup() -> Bool {
        HelixLogger.info("DebugHelper.checkAudioSetup is a no-op on this platform", category: .audio)
        return false
    }
}
#endif
