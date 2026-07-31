import Flutter
import Foundation
import WidgetKit

final class WidgetSnapshotBridge {
  static let shared = WidgetSnapshotBridge()

  private let ioQueue = DispatchQueue(
    label: "jp.kisou.widget.storage",
    qos: .utility
  )
  private var channel: FlutterMethodChannel?
  private var pendingHomeRoute = false
  private var routesDisabled: Bool
  private var routeEpoch = 0

  private init() {
    routesDisabled = Self.restoreDurableRouteLease()
  }

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "jp.kisou/widget",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "WIDGET_BRIDGE_UNAVAILABLE",
            message: "Widget bridge is unavailable.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "writeSnapshot":
        guard let raw = call.arguments as? String,
              let data = raw.data(using: .utf8)
        else {
          result(
            FlutterError(
              code: "INVALID_WIDGET_SNAPSHOT",
              message: "Widget snapshot must be JSON text.",
              details: nil
            )
          )
          return
        }
        self.routeEpoch += 1
        let operationEpoch = self.routeEpoch
        self.write(
          data: data,
          closeAccount: false,
          routesWereDisabled: self.routesDisabled,
          operationEpoch: operationEpoch,
          result: result
        )
      case "closeAccount":
        let routesWereDisabled = self.routesDisabled
        self.routeEpoch += 1
        let operationEpoch = self.routeEpoch
        self.routesDisabled = true
        self.pendingHomeRoute = false
        self.write(
          data: KisouWidgetShared.signedOutEnvelope,
          closeAccount: true,
          routesWereDisabled: routesWereDisabled,
          operationEpoch: operationEpoch,
          result: result
        )
      case "consumeInitialWidgetRoute":
        let pending = self.pendingHomeRoute && !self.routesDisabled
        self.pendingHomeRoute = false
        result(pending)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func handle(url: URL) -> Bool {
    guard isAllowedHomeURL(url) else {
      return false
    }
    guard !routesDisabled else {
      pendingHomeRoute = false
      return true
    }
    pendingHomeRoute = true
    channel?.invokeMethod("widgetHomeRoute", arguments: nil)
    return true
  }

  private func write(
    data: Data,
    closeAccount: Bool,
    routesWereDisabled: Bool,
    operationEpoch: Int,
    result: @escaping FlutterResult
  ) {
    ioQueue.async {
      do {
        if !closeAccount {
          try KisouWidgetSnapshotCodec.validateReadyEnvelope(data)
        }
        try self.writeDurably(data)
        WidgetCenter.shared.reloadTimelines(ofKind: KisouWidgetShared.kind)
        DispatchQueue.main.async {
          if closeAccount && operationEpoch == self.routeEpoch {
            // Make route clearing the final mutation before acknowledging the
            // signed-out file and timeline reload. Keep routes disabled until
            // the next account has published a valid ready snapshot.
            self.pendingHomeRoute = false
            self.routesDisabled = true
          } else if !closeAccount && operationEpoch == self.routeEpoch {
            // A same-account publish must not acknowledge a tap that Dart has
            // not consumed yet. Account close owns pending-route clearing.
            self.routesDisabled = false
          }
          result(nil)
        }
      } catch {
        DispatchQueue.main.async {
          if closeAccount && operationEpoch == self.routeEpoch {
            self.pendingHomeRoute = false
            self.routesDisabled = routesWereDisabled
          }
          result(
            FlutterError(
              code: "WIDGET_STORAGE_FAILED",
              message: "Could not update the widget snapshot.",
              details: nil
            )
          )
        }
      }
    }
  }

  private func writeDurably(_ data: Data) throws {
    guard let appGroup = Bundle.main.object(
      forInfoDictionaryKey: "KISOUWidgetAppGroup"
    ) as? String,
          !appGroup.isEmpty,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          )
    else {
      throw NSError(
        domain: "jp.kisou.widget",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Widget App Group is unavailable."]
      )
    }
    let directory = container.appendingPathComponent("Widget", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [
        .protectionKey:
          FileProtectionType.completeUntilFirstUserAuthentication
      ]
    )
    try FileManager.default.setAttributes(
      [
        .protectionKey:
          FileProtectionType.completeUntilFirstUserAuthentication
      ],
      ofItemAtPath: directory.path
    )
    var directoryValues = URLResourceValues()
    directoryValues.isExcludedFromBackup = true
    var mutableDirectory = directory
    try mutableDirectory.setResourceValues(directoryValues)

    var file = directory.appendingPathComponent("widget_snapshot.json")
    try data.write(
      to: file,
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    )
    var fileValues = URLResourceValues()
    fileValues.isExcludedFromBackup = true
    try file.setResourceValues(fileValues)
    let fileHandle = try FileHandle(forWritingTo: file)
    do {
      // Data.write(.atomic) publishes a complete replacement. Do not
      // acknowledge account cleanup until the replacement inode is synced.
      try fileHandle.synchronize()
      try fileHandle.close()
    } catch {
      try? fileHandle.close()
      throw error
    }
  }

  private func isAllowedHomeURL(_ url: URL) -> Bool {
    guard let scheme = Bundle.main.object(
      forInfoDictionaryKey: "KISOUWidgetURLScheme"
    ) as? String,
          !scheme.isEmpty,
          let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
          )
    else {
      return false
    }
    // URLComponents normalizes an absent port to nil and keeps user/query/
    // fragment separately, allowing an exact allow-list.
    return components.scheme == scheme &&
      components.host == "widget" &&
      components.path == "/home" &&
      components.user == nil &&
      components.password == nil &&
      components.port == nil &&
      components.query == nil &&
      components.fragment == nil
  }

  private static func restoreDurableRouteLease() -> Bool {
    guard let appGroup = Bundle.main.object(
      forInfoDictionaryKey: "KISOUWidgetAppGroup"
    ) as? String,
          !appGroup.isEmpty,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          )
    else {
      return true
    }
    let file = container.appendingPathComponent(
      KisouWidgetShared.snapshotRelativePath
    )
    guard FileManager.default.fileExists(atPath: file.path) else {
      return false
    }
    guard let attributes = try? FileManager.default.attributesOfItem(
      atPath: file.path
    ),
          let size = attributes[.size] as? NSNumber,
          size.intValue <= 8 * 1024,
          let data = try? Data(contentsOf: file),
          data.count <= 8 * 1024
    else {
      return true
    }
    if data == KisouWidgetShared.signedOutEnvelope {
      return true
    }
    return !KisouWidgetSnapshotCodec.isValidReadyEnvelope(data)
  }
}
