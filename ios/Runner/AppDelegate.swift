import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Channel for switching the app icon based on the in-app theme.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "kisou/app_icon",
        binaryMessenger: controller.binaryMessenger
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

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
