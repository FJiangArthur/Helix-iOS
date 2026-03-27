// ABOUTME: Singleton that auto-restarts the glasses mic every 28 seconds
// ABOUTME: for continuous active sessions. Emits health events to Dart via Flutter event channel.

import Foundation
import Flutter

class GlassesMicSessionManager {
    static let shared = GlassesMicSessionManager()

    private var restartTimer: Timer?
    private(set) var restartCount = 0
    private(set) var sessionStartTime: Date?
    private(set) var isActive = false
    var eventSink: FlutterEventSink?

    private let restartInterval: TimeInterval = 28.0

    func startContinuousSession() {
        guard !isActive else { return }
        isActive = true
        restartCount = 0
        sessionStartTime = Date()
        scheduleRestarts()
        emitHealthEvent()
    }

    func stopContinuousSession() {
        isActive = false
        restartTimer?.invalidate()
        restartTimer = nil
        emitHealthEvent()
    }

    private func scheduleRestarts() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: restartInterval, repeats: true) { [weak self] _ in
            self?.performRestart()
        }
    }

    private func performRestart() {
        guard isActive else { return }
        let recognizer = SpeechStreamRecognizer.shared

        // Stop current recognition briefly
        recognizer.stopRecognition(emitFinal: true)

        // Immediately restart (same config) at the native level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isActive else { return }
            recognizer.restartCurrentSession()
            self.restartCount += 1
            self.emitHealthEvent()
        }
    }

    private func emitHealthEvent() {
        let duration = sessionStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        let event: [String: Any] = [
            "restartCount": restartCount,
            "sessionDurationMs": duration,
            "isActive": isActive,
        ]
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }
}

class GlassesMicHealthEventHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        GlassesMicSessionManager.shared.eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        GlassesMicSessionManager.shared.eventSink = nil
        return nil
    }
}
