import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let ws = scene as? UIWindowScene,
       let rootVC = ws.windows.first?.rootViewController as? FlutterViewController,
       let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.setupChannels(with: rootVC)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if let ws = scene as? UIWindowScene,
       let rootVC = ws.windows.first?.rootViewController as? FlutterViewController,
       let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.setupChannels(with: rootVC)
    }
  }
}
