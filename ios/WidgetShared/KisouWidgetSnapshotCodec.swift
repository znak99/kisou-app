import CoreFoundation
import Foundation

enum KisouWidgetShared {
  static let schemaVersion = 1
  static let kind = "KisouDailyWidget"
  static let snapshotRelativePath = "Widget/widget_snapshot.json"
  static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

  static let signedOutEnvelope = Data(
    "{\"schema_version\":1,\"state\":\"signed_out\"}".utf8
  )
}

struct KisouWidgetReadySnapshot {
  let year: Int
  let month: Int
  let day: Int
  let validUntil: Date
  let feelingLabel: String
  let topLabel: String
  let bottomLabel: String
  let outerLabel: String

  var dateLabel: String {
    "\(month)/\(day)"
  }
}

enum KisouWidgetPresentation {
  case ready(KisouWidgetReadySnapshot)
  case placeholder(dateLabel: String)

  var dateLabel: String {
    switch self {
    case .ready(let snapshot):
      return snapshot.dateLabel
    case .placeholder(let dateLabel):
      return dateLabel
    }
  }
}

enum KisouWidgetSnapshotCodec {
  private static let feelingLabels = [
    "VERY_HOT": "とても暑く感じそうです",
    "HOT": "暑く感じそうです",
    "WARM": "暖かく感じそうです",
    "PERFECT": "ちょうど良く感じそうです",
    "COOL": "涼しく感じそうです",
    "COLD": "寒く感じそうです",
    "VERY_COLD": "とても寒く感じそうです",
  ]
  private static let topLabels = [
    "SLEEVELESS": "タンクトップ",
    "SHORT_SLEEVE": "半袖",
    "THIN_LONG": "薄手の長袖",
    "LONG_SLEEVE": "長袖",
    "THICK_LONG": "厚手の長袖",
    "KNIT_SWEAT": "ニット・スウェット",
  ]
  private static let bottomLabels = [
    "LONG_PANTS": "長ズボン",
    "HALF_PANTS": "半ズボン",
    "SHORT_PANTS": "ショートパンツ",
    "SKIRT": "スカート",
  ]
  private static let outerLabels = [
    "LIGHT_OUTER": "薄手の羽織り",
    "CARDIGAN": "カーディガン",
    "JACKET": "ジャケット",
    "COAT": "コート",
    "PADDING": "ダウン",
  ]

  static func validateReadyEnvelope(_ data: Data) throws {
    guard parseReady(data) != nil else {
      throw NSError(
        domain: "jp.kisou.widget",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid widget snapshot."]
      )
    }
  }

  static func isValidReadyEnvelope(_ data: Data) -> Bool {
    parseReady(data) != nil
  }

  static func presentation(
    from data: Data?,
    now: Date = Date()
  ) -> KisouWidgetPresentation {
    let today = tokyoComponents(now)
    let placeholder = KisouWidgetPresentation.placeholder(
      dateLabel: "\(today.month ?? 1)/\(today.day ?? 1)"
    )
    guard let data,
          let snapshot = parseReady(data),
          snapshot.year == today.year,
          snapshot.month == today.month,
          snapshot.day == today.day,
          now < snapshot.validUntil
    else {
      return placeholder
    }
    return .ready(snapshot)
  }

  static func parseReady(_ data: Data) -> KisouWidgetReadySnapshot? {
    guard data.count <= 8 * 1024,
          let object = try? JSONSerialization.jsonObject(with: data),
          let root = object as? [String: Any],
          hasExactKeys(
            root,
            expected: [
              "schema_version",
              "state",
              "date",
              "valid_until",
              "feeling",
              "recommendation",
            ]
          ),
          let schema = root["schema_version"] as? NSNumber,
          CFGetTypeID(schema) == CFNumberGetTypeID(),
          !CFNumberIsFloatType(schema as CFNumber),
          schema.intValue == KisouWidgetShared.schemaVersion,
          let state = root["state"] as? String,
          state == "ready",
          let rawDate = root["date"] as? String,
          let dateParts = parseCanonicalDate(rawDate),
          let rawValidUntil = root["valid_until"] as? String,
          let validUntil = parseCanonicalExpiry(rawValidUntil),
          validUntil == nextTokyoMidnight(
            year: dateParts.year,
            month: dateParts.month,
            day: dateParts.day
          ),
          let feeling = root["feeling"] as? String,
          let feelingLabel = feelingLabels[feeling],
          let recommendation = root["recommendation"] as? [String: Any],
          hasExactKeys(
            recommendation,
            expected: ["top", "bottom", "outer"]
          ),
          let top = recommendation["top"] as? String,
          let topLabel = topLabels[top],
          let bottom = recommendation["bottom"] as? String,
          let bottomLabel = bottomLabels[bottom]
    else {
      return nil
    }

    let outer: String?
    let outerLabel: String
    if recommendation["outer"] is NSNull {
      outer = nil
      outerLabel = "アウターなし"
    } else if let rawOuter = recommendation["outer"] as? String,
              let mapped = outerLabels[rawOuter] {
      outer = rawOuter
      outerLabel = mapped
    } else {
      return nil
    }
    guard canonicalReadyEnvelope(
      date: rawDate,
      validUntil: rawValidUntil,
      feeling: feeling,
      top: top,
      bottom: bottom,
      outer: outer
    ) == data else {
      return nil
    }
    return KisouWidgetReadySnapshot(
      year: dateParts.year,
      month: dateParts.month,
      day: dateParts.day,
      validUntil: validUntil,
      feelingLabel: feelingLabel,
      topLabel: topLabel,
      bottomLabel: bottomLabel,
      outerLabel: outerLabel
    )
  }

  static func tokyoDateLabel(_ date: Date) -> String {
    let components = tokyoComponents(date)
    return "\(components.month ?? 1)/\(components.day ?? 1)"
  }

  static func nextTokyoMidnight(after date: Date) -> Date {
    let components = tokyoComponents(date)
    return nextTokyoMidnight(
      year: components.year!,
      month: components.month!,
      day: components.day!
    )!
  }

  private static func hasExactKeys(
    _ value: [String: Any],
    expected: Set<String>
  ) -> Bool {
    Set(value.keys) == expected
  }

  private static func canonicalReadyEnvelope(
    date: String,
    validUntil: String,
    feeling: String,
    top: String,
    bottom: String,
    outer: String?
  ) -> Data {
    let encodedOuter = outer.map { "\"\($0)\"" } ?? "null"
    let raw = "{\"schema_version\":1,\"state\":\"ready\"," +
      "\"date\":\"\(date)\",\"valid_until\":\"\(validUntil)\"," +
      "\"feeling\":\"\(feeling)\",\"recommendation\":{" +
      "\"top\":\"\(top)\",\"bottom\":\"\(bottom)\"," +
      "\"outer\":\(encodedOuter)}}"
    return Data(raw.utf8)
  }

  private static func parseCanonicalDate(
    _ value: String
  ) -> (year: Int, month: Int, day: Int)? {
    guard value.range(
      of: #"^\d{4}-\d{2}-\d{2}$"#,
      options: .regularExpression
    ) != nil else {
      return nil
    }
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let day = Int(parts[2])
    else {
      return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = KisouWidgetShared.tokyoTimeZone
    let components = DateComponents(
      timeZone: KisouWidgetShared.tokyoTimeZone,
      year: year,
      month: month,
      day: day
    )
    guard let date = calendar.date(from: components) else {
      return nil
    }
    let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
    guard roundTrip.year == year,
          roundTrip.month == month,
          roundTrip.day == day
    else {
      return nil
    }
    return (year, month, day)
  }

  private static func parseCanonicalExpiry(_ value: String) -> Date? {
    guard value.range(
      of: #"^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\dZ$"#,
      options: .regularExpression
    ) != nil else {
      return nil
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let parsed = formatter.date(from: value),
          formatter.string(from: parsed) == value
    else {
      return nil
    }
    return parsed
  }

  private static func nextTokyoMidnight(
    year: Int,
    month: Int,
    day: Int
  ) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = KisouWidgetShared.tokyoTimeZone
    let start = calendar.date(
      from: DateComponents(
        timeZone: KisouWidgetShared.tokyoTimeZone,
        year: year,
        month: month,
        day: day
      )
    )
    return start.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
  }

  private static func tokyoComponents(_ date: Date) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = KisouWidgetShared.tokyoTimeZone
    return calendar.dateComponents([.year, .month, .day], from: date)
  }
}
