import Flutter
import UIKit

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

    // Register the app-icon channel on the implicit engine's messenger.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KisouAppIcon") {
      let channel = FlutterMethodChannel(
        name: "kisou/app_icon",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, reply in
        guard call.method == "setIcon" else {
          reply(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let name = args?["name"] as? String // nil → primary (light) icon
        guard UIApplication.shared.supportsAlternateIcons else {
          reply(FlutterError(code: "UNSUPPORTED",
                             message: "Alternate icons not supported", details: nil))
          return
        }
        DispatchQueue.main.async {
          // Skip if already showing the requested icon — avoids the system
          // "icon changed" alert firing on every launch.
          if UIApplication.shared.alternateIconName == name {
            reply(nil)
            return
          }
          UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
              reply(FlutterError(code: "ICON_ERROR",
                                 message: error.localizedDescription, details: nil))
            } else {
              reply(nil)
            }
          }
        }
      }
    }
  }
}
