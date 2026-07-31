import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    if let url = launchOptions?[.url] as? URL {
      _ = WidgetSnapshotBridge.shared.handle(url: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "jp.kisou/travel_storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "prepareTravelDatabaseDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        result(try Self.prepareTravelDatabaseDirectory())
      } catch {
        result(
          FlutterError(
            code: "TRAVEL_STORAGE_PROTECTION_FAILED",
            message: "Could not prepare protected local travel storage.",
            details: error.localizedDescription
          )
        )
      }
    }
    let pushChannel = FlutterMethodChannel(
      name: "jp.kisou/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel.setMethodCallHandler { call, result in
      guard call.method == "clearDisplayedPushNotifications" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let center = UNUserNotificationCenter.current()
      center.getDeliveredNotifications { notifications in
        let identifiers = notifications.compactMap { notification in
          notification.request.content.threadIdentifier == "kisou_daily_push_v1"
            ? notification.request.identifier
            : nil
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        DispatchQueue.main.async {
          result(nil)
        }
      }
    }
    WidgetSnapshotBridge.shared.configure(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if WidgetSnapshotBridge.shared.handle(url: url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private static func prepareTravelDatabaseDirectory() throws -> String {
    let fileManager = FileManager.default
    guard let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw NSError(
        domain: "jp.kisou.travel_storage",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Application Support is unavailable."]
      )
    }

    var directory = applicationSupport.appendingPathComponent(
      "TravelPlans",
      isDirectory: true
    )
    let protection: [FileAttributeKey: Any] = [
      .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
    ]
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: protection
    )
    try fileManager.setAttributes(protection, ofItemAtPath: directory.path)

    var directoryValues = URLResourceValues()
    directoryValues.isExcludedFromBackup = true
    try directory.setResourceValues(directoryValues)

    let legacyFiles = try migrateLegacyTravelDatabase(
      fileManager: fileManager,
      destination: directory
    )
    let existingFiles = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: []
    )
    for var file in existingFiles {
      try fileManager.setAttributes(protection, ofItemAtPath: file.path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try file.setResourceValues(values)
    }
    for legacyFile in legacyFiles {
      try fileManager.removeItem(at: legacyFile)
    }
    return directory.path
  }

  private static func migrateLegacyTravelDatabase(
    fileManager: FileManager,
    destination: URL
  ) throws -> [URL] {
    guard let documents = fileManager.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return []
    }
    let databaseName = "kisou_travel_plans.db"
    let legacyDatabase = documents.appendingPathComponent(databaseName)
    guard fileManager.fileExists(atPath: legacyDatabase.path) else {
      return []
    }

    var copiedLegacyFiles: [URL] = []
    for suffix in ["", "-wal", "-shm"] {
      let source = documents.appendingPathComponent(databaseName + suffix)
      guard fileManager.fileExists(atPath: source.path) else {
        continue
      }
      let target = destination.appendingPathComponent(databaseName + suffix)
      if fileManager.fileExists(atPath: target.path) {
        try fileManager.removeItem(at: target)
      }
      try fileManager.copyItem(at: source, to: target)
      copiedLegacyFiles.append(source)
    }
    return copiedLegacyFiles
  }
}
