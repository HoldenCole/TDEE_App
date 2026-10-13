import SwiftUI
import Charts
import TareEngine

/// One chart style for the whole app (SCREENS.md rule 5).
extension View {
    func tareChartAxes(xCount: Int = 3, yCount: Int = 3, yFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))) -> some View {
        self
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: yCount)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.hairline)
                    AxisValueLabel(format: yFormat).font(Theme.axis()).foregroundStyle(Theme.tertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xCount)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
                }
            }
            .chartLegend(.hidden)
    }
}

struct DatedValue: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// One stretch of a phase, for shading charts and drawing a line where the phase changed.
struct PhaseSpan: Identifiable, Equatable {
    let phase: Phase
    let start: Date
    let end: Date
    /// True when the span begins with a switch inside the chart range (draw the line).
    let startsWithSwitch: Bool
    var label: String? = nil
    var id: Date { start }

    var title: String { label ?? phase.title }

    var color: Color {
        if label != nil { return Theme.good }
        switch phase {
        case .cut: return Theme.behindBar
        case .leanBulk, .bulk: return Theme.accent
        case .recomp, .maintain: return Theme.good
        }
    }
}

/// Shading and switch lines shared by every time chart.
struct PhaseLayer: ChartContent {
    let spans: [PhaseSpan]

    var body: some ChartContent {
        ForEach(spans) { span in
            RectangleMark(xStart: .value("Start", span.start), xEnd: .value("End", span.end))
                .foregroundStyle(span.color.opacity(0.06))
            if span.startsWithSwitch {
                RuleMark(x: .value("Phase", span.start))
                    .foregroundStyle(span.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .bottom, alignment: .leading, spacing: 2, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text(span.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(span.color)
                    }
            }
        }
    }
}

/// A marker for a dial change or accepted recommendation on a time chart.
struct ChartMarker: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let label: String
}

extension ChartMarker {
    init(change: DialChange) {
        self.id = change.id
        self.date = change.date
        let title = change.title
        if case .date = change.newValue {
            // A date dial's old value is noise on a chart; "Diet break starts · Oct 13" is enough.
            self.label = "\(title) · \(change.newDescription)"
        } else {
            self.label = "\(title) \(change.oldDescription) → \(change.newDescription)"
        }
    }
}

/// The weight chart: weigh-ins as dots, trend as the accent line with a soft area, markers for dial changes.
struct WeightChart: View {
    let points: [TrendPoint]
    var markers: [ChartMarker] = []
    var phases: [PhaseSpan] = []
    var goalPath: [DatedValue] = []
    var showDots = true
    var height: CGFloat = 220

    private var domain: ClosedRange<Double> {
        let values = points.map(\.weightLb) + points.map(\.trendLb) + goalPath.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max(1, (hi - lo) * 0.25)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        Chart {
            PhaseLayer(spans: phases)
            if !points.isEmpty {
                ForEach(points) { p in
                    AreaMark(x: .value("Date", p.date), yStart: .value("Base", domain.lowerBound), yEnd: .value("Trend", p.trendLb))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.14), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", p.date), y: .value("Trend", p.trendLb), series: .value("Series", "trend"))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                if showDots {
                    ForEach(points) { p in
                        PointMark(x: .value("Date", p.date), y: .value("Weigh-in", p.weightLb))
                            .foregroundStyle(p.isOutlier ? Theme.tertiary.opacity(0.4) : Theme.tertiary)
                            .symbolSize(18)
                    }
                }
                ForEach(goalPath) { g in
                    LineMark(x: .value("Date", g.date), y: .value("Goal", g.value), series: .value("Series", "goal"))
                        .foregroundStyle(Theme.tertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                ForEach(markers) { m in
                    RuleMark(x: .value("Change", m.date))
                        .foregroundStyle(Theme.behindBar)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 2, overflowResolution: .init(x: .fit, y: .disabled)) {
                            Text(m.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.behind).lineLimit(1)
                        }
                }
                if let last = points.last {
                    PointMark(x: .value("Date", last.date), y: .value("Trend", last.trendLb))
                        .symbol {
                            Circle().strokeBorder(Theme.accent, lineWidth: 2.5).background(Circle().fill(Theme.surface)).frame(width: 14, height: 14)
                        }
                        .annotation(position: .trailing, spacing: 4, overflowResolution: .init(x: .fit, y: .fit)) {
                            Text(Fmt.lb(last.trendLb)).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
                        }
                }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 36))
        .tareChartAxes()
        .frame(height: height)
    }
}

/// A generic accent line with area fill and a ringed last point, for the detail sheet.
struct LineSeriesChart: View {
    let series: [DatedValue]
    var secondary: [DatedValue] = []
    var dashed: [DatedValue] = []
    var bars: [DatedValue] = []
    var markers: [ChartMarker] = []
    var phases: [PhaseSpan] = []
    var unit: String = ""
    var height: CGFloat = 220
    var yDigits: Int = 0

    private var domain: ClosedRange<Double> {
        let values = series.map(\.value) + secondary.map(\.value) + dashed.map(\.value) + bars.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max(hi == lo ? 1 : 0, (hi - lo) * 0.3)
        let low = bars.isEmpty ? lo - pad : min(0, lo - pad)
        return low...(hi + pad)
    }

    var body: some View {
        Chart {
            PhaseLayer(spans: phases)
            ForEach(bars) { b in
                BarMark(x: .value("Date", b.date, unit: .day), y: .value("Value", b.value))
                    .foregroundStyle(Theme.track)
                    .cornerRadius(2)
            }
            ForEach(series) { p in
                AreaMark(x: .value("Date", p.date), yStart: .value("Base", domain.lowerBound), yEnd: .value("Value", p.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.14), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "main"))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
            ForEach(secondary) { p in
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "secondary"))
                    .foregroundStyle(Theme.accent.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            ForEach(dashed) { p in
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "dashed"))
                    .foregroundStyle(Theme.tertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            ForEach(markers) { m in
                RuleMark(x: .value("Change", m.date))
                    .foregroundStyle(Theme.behindBar)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 2, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text(m.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.behind).lineLimit(1)
                    }
            }
            if let last = series.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value))
                    .symbol {
                        Circle().strokeBorder(Theme.accent, lineWidth: 2.5).background(Circle().fill(Theme.surface)).frame(width: 14, height: 14)
                    }
                    .annotation(position: .trailing, spacing: 4, overflowResolution: .init(x: .fit, y: .fit)) {
                        Text(yDigits == 0 ? Fmt.int(last.value) : Fmt.dec(last.value, yDigits)).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiary)
                    }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 36))
        .tareChartAxes(yFormat: .number.precision(.fractionLength(yDigits)))
        .frame(height: height)
    }
}
