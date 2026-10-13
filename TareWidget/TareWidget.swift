import WidgetKit
import SwiftUI

struct TareEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TareProvider: TimelineProvider {
    func placeholder(in context: Context) -> TareEntry {
        TareEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TareEntry) -> Void) {
        completion(TareEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TareEntry>) -> Void) {
        let entry = TareEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .placeholder)
        // The app reloads timelines whenever Health delivers new samples; this is a fallback refresh.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TareWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TareEntry

    private var s: WidgetSnapshot { entry.snapshot }
    private var remaining: String { format(s.remaining) }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                family == .systemSmall ? Color(uiColor: .systemBackground) : Color.clear
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(remaining).font(.system(size: 16, weight: .bold)).monospacedDigit().minimumScaleFactor(0.6)
                    Text("left").font(.system(size: 9))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(remaining) kcal left").font(.system(size: 15, weight: .bold)).monospacedDigit()
                Text("of \(format(s.targetCalories)) · \(s.isTrainingDay ? "training" : "rest")").font(.system(size: 12))
                ProgressView(value: s.progress).tint(.white)
            }
        case .accessoryInline:
            Text("\(remaining) kcal left")
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("REMAINING").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Color.secondary)
                Text(remaining).font(.system(size: 40, weight: .bold)).monospacedDigit().tracking(-1.5).foregroundStyle(Color.primary).minimumScaleFactor(0.6)
                Text("of \(format(s.targetCalories)) kcal").font(.system(size: 13)).foregroundStyle(Color.secondary)
                Spacer(minLength: 4)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule().fill(Color.primary).frame(width: geo.size.width * s.progress)
                    }
                }
                .frame(height: 5)
                Text(s.isTrainingDay ? "Training day" : "Rest day").font(.system(size: 11, weight: .semibold)).foregroundStyle(s.isTrainingDay ? Color.accentColor : Color.secondary)
            }
        }
    }

    private func format(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }
}

struct TareWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TareWidget", provider: TareProvider()) { entry in
            TareWidgetView(entry: entry)
        }
        .configurationDisplayName("Calories remaining")
        .description("Today's target and what's left.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct TareWidgetBundle: WidgetBundle {
    var body: some Widget {
        TareWidget()
    }
}
