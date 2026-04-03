import Flutter
import UIKit

/// UIScene + Implicit Flutter 引擎（Flutter 3.41+ 官方迁移）。
/// 插件注册必须在 `didInitializeImplicitFlutterEngine`，勿在 `didFinishLaunching` 里再 `register`。
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
