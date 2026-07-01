import UIKit

extension Notification.Name {
    static let helixLiveActivityButtonPressed = Notification.Name("helixLiveActivityButtonPressed")
}

@main
@objc final class AppDelegate: UIResponder, UIApplicationDelegate {
    private var didRegisterLiveActivityButtonObservers = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.cleanupStaleActivities()
        }

        registerLiveActivityButtonObservers()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func registerLiveActivityButtonObservers() {
        guard !didRegisterLiveActivityButtonObservers else { return }
        didRegisterLiveActivityButtonObservers = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CFNotificationCallback = { _, observer, name, _, _ in
            guard let observer, let name else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
            let rawName = name.rawValue as String
            DispatchQueue.main.async {
                delegate.forwardLiveActivityButton(rawName: rawName)
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
        guard let button = HelixLiveActivityIntentBridge.Button(rawValue: rawName) else {
            return
        }

        let id: String
        switch button {
        case .askQuestion:
            id = "askQuestion"
        case .pauseTranscription:
            id = "pauseTranscription"
        case .resumeTranscription:
            id = "resumeTranscription"
        }

        NotificationCenter.default.post(
            name: .helixLiveActivityButtonPressed,
            object: nil,
            userInfo: ["button": id]
        )
    }
}
