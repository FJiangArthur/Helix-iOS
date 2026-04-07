import Foundation

/// Darwin notification names + post helper shared by the widget extension
/// and the host app. Button taps in the Live Activity post via this bridge;
/// the host app's AppDelegate listens and forwards to Flutter.
enum HelixLiveActivityIntentBridge {
    enum Button: String {
        case askQuestion         = "com.helix.liveactivity.askQuestion"
        case pauseTranscription  = "com.helix.liveactivity.pauseTranscription"
        case resumeTranscription = "com.helix.liveactivity.resumeTranscription"
    }

    static func post(_ button: Button) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(button.rawValue as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }
}
