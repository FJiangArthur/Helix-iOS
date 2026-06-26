import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        DispatchQueue.main.async { [weak self] in
            self?.configureInputInspectorHost(in: scene)
        }
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        configureInputInspectorHost(in: scene)
    }

    private func configureInputInspectorHost(in scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let controller = windowScene.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? FlutterViewController
            ?? windowScene.windows.first?.rootViewController as? FlutterViewController

        if let controller {
            InputInspectorController.shared.configure(host: controller)
        }
    }
}
