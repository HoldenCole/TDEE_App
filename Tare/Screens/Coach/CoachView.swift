import SwiftUI
import Charts
import TareEngine

/// Full-screen recommendation: the chart, the math line by line, what changes if you accept.
struct CoachView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let recommendation: CoachRecommendation
    let recordID: UUID

    @State private var editing = false
    @State private var amount: Double

    init(recommendation: CoachRecommendation, recordID: UUID) {
        self.recommendation = recommendation
        self.recordID = recordID
        _amount = State(initialValue: recommendation.kcalChange ?? 0)
    }

    private var rec: CoachRecommendation { recommendation }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.bottom, 26)
                    if let chart = rec.chart {
                        CoachChartView(chart: chart)
                            .padding(.bottom, 22)
                        Hairline().padding(.bottom, 22)
                    }
                    Eyebrow("The math").padding(.bottom, 6)
                    mathRows.padding(.bottom, 22)
                    Hairline().padding(.bottom, 22)
                    Eyebrow("If you accept").padding(.bottom, 8)
                    ifAccept
                    if editing { editor.padding(.top, 20) }
                }
                .padding(.horizontal, Theme.sideMargin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            buttons
        }
        .background(Theme.surface)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundIconButton(systemName: "chevron.left") {
                model.showCoachScreen = false
                dismiss()
            }
            .padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Coach · \(Format.weekdayName(model.dials.coachCheckInWeekday, calendar: .current)) check-in", color: Theme.accent)
                Text(rec.headline).titleStyle().fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 28)
    }

    private var mathRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(rec.math.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label).font(.system(size: 17)).foregroundStyle(Theme.secondary)
                    Spacer()
                    if let id = row.numberID, let number = NumberID.parse(id) {
                        DottedNumber(text: row.value, number: number, font: .system(size: 17, weight: .bold))
                    } else {
                        Text(row.value).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(row.highlighted ? Theme.accent : Theme.ink)
                    }
                }
                .padding(.vertical, 11)
            }
        }
    }

    private var ifAccept: some View {
        Text(ifAcceptText)
            .font(.system(size: 17)).foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var ifAcceptText: String {
        guard editing, rec.kcalChange != nil, amount != rec.kcalChange else { return rec.ifAccepted }
        let t = model.snapshot.targets
        return "Training days go to \(Fmt.int(t.training.calories + amount)), rest days to \(Fmt.int(t.rest.calories + amount)). Carbs take the \(amount >= 0 ? "extra" : "cut"). The change is logged and marked on your Trend chart."
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Edit amount")
            HStack {
                Text("\(Fmt.signed(amount, 0)) kcal/day").font(.system(size: 22, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                Spacer()
                Stepper("", value: $amount, in: -500...500, step: 10).labelsHidden()
            }
            TareSlider(value: $amount, range: -500...500, step: 10, tint: Theme.accent)
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            if rec.hasProposal {
                InkButton(title: rec.kcalChange != nil ? "Accept \(Fmt.signed(amount, 0))" : "Accept", expand: true) {
                    model.accept(recordID: recordID, kcalOverride: editing ? amount : nil)
                    model.showCoachScreen = false
                    dismiss()
                }
                if rec.kcalChange != nil {
                    PillButton(title: "Edit amount") { withAnimation { editing.toggle() } }
                }
            } else {
                InkButton(title: "Got it") {
                    model.accept(recordID: recordID, kcalOverride: nil)
                    model.showCoachScreen = false
                    dismiss()
                }
            }
            PillButton(title: "Later", tint: Theme.secondary) {
                model.snooze(recordID: recordID)
                model.showCoachScreen = false
                dismiss()
            }
        }
        .padding(.horizontal, Theme.sideMargin)
        .padding(.vertical, 12)
        .background(Theme.surface)
    }
}

/// Renders a `CoachChart` from the engine with the shared chart style.
struct CoachChartView: View {
    let chart: CoachChart

    private var domain: ClosedRange<Double> {
        let values = chart.series.flatMap { $0.points.map(\.value) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let hasBars = chart.series.contains { $0.style == .bars }
        let pad = max(hi == lo ? 1 : 0, (hi - lo) * 0.3)
        return (hasBars ? min(0, lo - pad) : lo - pad)...(hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(chart.title)
            Text(chart.caption).font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            Chart {
                ForEach(Array(chart.series.enumerated()), id: \.offset) { index, series in
                    ForEach(Array(series.points.enumerated()), id: \.offset) { _, p in
                        switch series.style {
                        case .line:
                            LineMark(x: .value("Date", p.date), y: .value(series.name, p.value), series: .value("S", series.name))
                                .foregroundStyle(index == 0 ? Theme.accent : Theme.accent.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.catmullRom)
                        case .dashed:
                            LineMark(x: .value("Date", p.date), y: .value(series.name, p.value), series: .value("S", series.name))
                                .foregroundStyle(Theme.tertiary)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        case .bars:
                            BarMark(x: .value("Date", p.date, unit: .day), y: .value(series.name, p.value))
                                .foregroundStyle(Theme.accent)
                                .cornerRadius(3)
                        }
                    }
                    if series.style == .line, let last = series.points.last, index == 0 {
                        PointMark(x: .value("Date", last.date), y: .value(series.name, last.value))
                            .symbol {
                                Circle().strokeBorder(Theme.accent, lineWidth: 2.5).background(Circle().fill(Color.white)).frame(width: 14, height: 14)
                            }
                    }
                }
            }
            .chartYScale(domain: domain)
            .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 20))
            .tareChartAxes(yFormat: .number.precision(.fractionLength(chart.unit == "lb" ? 1 : 0)))
            .frame(height: 220)
            .padding(.top, 8)
            HStack(spacing: 14) {
                ForEach(Array(chart.series.enumerated()), id: \.offset) { index, series in
                    HStack(spacing: 5) {
                        Rectangle().fill(series.style == .dashed ? Theme.tertiary : (index == 0 ? Theme.accent : Theme.accent.opacity(0.5))).frame(width: 14, height: 2)
                        Text(series.name).font(Theme.captionSmall()).foregroundStyle(Theme.secondary)
                    }
                }
            }
        }
    }
}

/// Past recommendations, reachable from the Coach screen when nothing is open.
struct CoachHistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen {
            HStack(alignment: .top, spacing: 14) {
                RoundIconButton(systemName: "chevron.left") {
                    model.showCoachScreen = false
                    dismiss()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Coach", color: Theme.accent)
                    Text("Check-ins").titleStyle()
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            let all = model.allRecommendations()
            if all.isEmpty {
                EmptyHint(text: "The coach checks your week every \(Format.weekdayName(model.dials.coachCheckInWeekday, calendar: .current)). Nothing yet.")
            }
            ForEach(all) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.headline).font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(r.status.rawValue.capitalized).font(Theme.caption()).foregroundStyle(r.status == .accepted ? Theme.good : Theme.secondary)
                    }
                    Text("\(Fmt.mediumDate(r.date)) · \(r.rule.title)").font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
                .padding(.vertical, 12)
                Hairline()
            }
            PillButton(title: "Run a check-in now") { model.runCoachNow() }
                .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
