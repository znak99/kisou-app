import SwiftUI
import WidgetKit

struct KisouWidgetEntry: TimelineEntry {
  let date: Date
  let presentation: KisouWidgetPresentation
}

struct KisouWidgetTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> KisouWidgetEntry {
    let now = Date()
    return KisouWidgetEntry(
      date: now,
      presentation: .placeholder(
        dateLabel: KisouWidgetSnapshotCodec.tokyoDateLabel(now)
      )
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (KisouWidgetEntry) -> Void
  ) {
    let now = Date()
    completion(
      KisouWidgetEntry(
        date: now,
        presentation: loadPresentation(now: now)
      )
    )
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<KisouWidgetEntry>) -> Void
  ) {
    let now = Date()
    let current = loadPresentation(now: now)
    let boundary: Date
    switch current {
    case .ready(let snapshot):
      boundary = snapshot.validUntil
    case .placeholder:
      boundary = KisouWidgetSnapshotCodec.nextTokyoMidnight(after: now)
    }
    let entries = [
      KisouWidgetEntry(date: now, presentation: current),
      KisouWidgetEntry(
        date: boundary,
        presentation: .placeholder(
          dateLabel: KisouWidgetSnapshotCodec.tokyoDateLabel(boundary)
        )
      ),
    ]
    // The app owns network refreshes. This boundary entry only makes an old
    // recommendation fail closed; WidgetKit may apply it later than requested.
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func loadPresentation(now: Date) -> KisouWidgetPresentation {
    guard let appGroup = Bundle.main.object(
      forInfoDictionaryKey: "KISOUWidgetAppGroup"
    ) as? String,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          )
    else {
      return .placeholder(
        dateLabel: KisouWidgetSnapshotCodec.tokyoDateLabel(now)
      )
    }
    let file = container.appendingPathComponent(
      KisouWidgetShared.snapshotRelativePath
    )
    let data: Data?
    if let attributes = try? FileManager.default.attributesOfItem(
      atPath: file.path
    ),
       let size = attributes[.size] as? NSNumber,
       size.intValue <= 8 * 1024 {
      data = try? Data(contentsOf: file, options: [.mappedIfSafe])
    } else {
      data = nil
    }
    return KisouWidgetSnapshotCodec.presentation(from: data, now: now)
  }
}

struct KisouWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.colorScheme) private var colorScheme
  let entry: KisouWidgetEntry

  var body: some View {
    widgetContainer
    .widgetURL(homeURL)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var widgetContainer: some View {
    if #available(iOS 17.0, *) {
      content
        .containerBackground(for: .widget) {
          Color(.systemBackground)
        }
    } else {
      ZStack {
        Color(.systemBackground)
        content
          .padding(16)
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch entry.presentation {
    case .ready(let snapshot):
      VStack(
        alignment: .leading,
        spacing: usesCompactAccessibilityLayout ? 3 : 8
      ) {
        header
        if !usesCompactAccessibilityLayout {
          Text(snapshot.feelingLabel)
            .font(.caption.weight(.bold))
            .foregroundColor(feelingColor)
            .lineLimit(2)
        }
        if usesCompactAccessibilityLayout {
          compactGarment(snapshot.outerLabel)
          compactGarment(snapshot.topLabel)
          compactGarment(snapshot.bottomLabel)
        } else if family == .systemMedium &&
                    !sizeCategory.isAccessibilityCategory {
          HStack(spacing: 8) {
            garmentCard("アウター", snapshot.outerLabel)
            garmentCard("トップス", snapshot.topLabel)
            garmentCard("ボトムス", snapshot.bottomLabel)
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            garmentLine("アウター", snapshot.outerLabel)
            garmentLine("トップス", snapshot.topLabel)
            garmentLine("ボトムス", snapshot.bottomLabel)
          }
        }
      }
      .privacySensitive()
      .accessibilityLabel(
        "\(snapshot.dateLabel)のおすすめ。\(snapshot.feelingLabel)。" +
          "アウター、\(snapshot.outerLabel)。トップス、\(snapshot.topLabel)。" +
          "ボトムス、\(snapshot.bottomLabel)。"
      )
    case .placeholder:
      VStack(alignment: .leading, spacing: 12) {
        header
        Spacer(minLength: 0)
        Label("アプリを開いて更新", systemImage: "arrow.clockwise")
          .font(.caption.weight(.bold))
          .foregroundColor(softInkColor)
          .lineLimit(3)
        Spacer(minLength: 0)
      }
      .accessibilityLabel(
        "\(entry.presentation.dateLabel)のおすすめはまだ更新されていません。" +
          "ダブルタップしてアプリを開きます。"
      )
    }
  }

  @ViewBuilder
  private var header: some View {
    if usesCompactAccessibilityLayout {
      Text(entry.presentation.dateLabel)
        .font(.caption2.weight(.bold))
        .foregroundColor(softInkColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    } else {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("今日のおすすめ")
          .font(.caption.weight(.bold))
          .foregroundColor(.primary)
          .lineLimit(2)
        Spacer(minLength: 4)
        Text(entry.presentation.dateLabel)
          .font(.caption2.weight(.bold))
          .foregroundColor(softInkColor)
      }
    }
  }

  private func compactGarment(_ label: String) -> some View {
    Text(label)
      .font(.caption2.weight(.semibold))
      .foregroundColor(.primary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
  }

  private func garmentLine(_ category: String, _ label: String) -> some View {
    Text("\(category)  \(label)")
      .font(.caption2.weight(.semibold))
      .foregroundColor(.primary)
      .lineLimit(2)
  }

  private func garmentCard(_ category: String, _ label: String) -> some View {
    VStack(spacing: 3) {
      Text(category)
        .font(.caption2)
        .foregroundColor(softInkColor)
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(6)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var homeURL: URL? {
    guard let scheme = Bundle.main.object(
      forInfoDictionaryKey: "KISOUWidgetURLScheme"
    ) as? String else {
      return nil
    }
    return URL(string: "\(scheme)://widget/home")
  }

  private var usesCompactAccessibilityLayout: Bool {
    sizeCategory.isAccessibilityCategory
  }

  // Both values exceed 4.5:1 against their corresponding system background.
  private var feelingColor: Color {
    if colorScheme == .dark {
      return Color(red: 0.722, green: 0.745, blue: 1.000)
    }
    return Color(red: 0.298, green: 0.357, blue: 0.800)
  }

  private var softInkColor: Color {
    if colorScheme == .dark {
      return Color(red: 0.690, green: 0.710, blue: 0.749)
    }
    return Color(red: 0.420, green: 0.447, blue: 0.502)
  }
}

@main
struct KisouDailyWidget: Widget {
  let kind = KisouWidgetShared.kind

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: KisouWidgetTimelineProvider()
    ) { entry in
      KisouWidgetView(entry: entry)
    }
    .configurationDisplayName("今日のおすすめ")
    .description("KISOUの今日の服装おすすめを表示します。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
