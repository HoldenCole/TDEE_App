import SwiftUI
import TareEngine

enum ChartRange: Hashable, CaseIterable {
    case sixWeeks, threeMonths, oneYear

    var title: String {
        switch self {
        case .sixWeeks: return "6W"
        case .threeMonths: return "3M"
        case .oneYear: return "1Y"
        }
    }

    var days: Int {
        switch self {
        case .sixWeeks: return 42
        case .threeMonths: return 91
        case .oneYear: return 365
        }
    }

    func start(from date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: date)) ?? date
    }
}

struct TrendView: View {
    @Environment(AppModel.self) private var model
    @State private var range: ChartRange = .sixWeeks

    private var s: EngineSnapshot { model.snapshot }
    private var d: Dials { model.dials }

    private var points: [TrendPoint] {
        let start = range.start()
        return s.trend.filter { $0.date >= start }
    }

    private var changeSinceStart: Double? {
        guard let first = points.first, let last = points.last, first.date < last.date else { return nil }
        return last.trendLb - first.trendLb
    }

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: kicker, title: "Trend") {
                    SegmentedPills(options: ChartRange.allCases.map { ($0, $0.title) }, selection: $range)
                }
                .padding(.bottom, 26)

                trendWeight
                    .padding(.bottom, 16)

                if points.count >= 2 {
                    WeightChart(points: points, markers: model.chartMarkers(from: range.start()).map(ChartMarker.init(change:)))
                    Text("Dots are daily weigh-ins. The line ignores water and sodium swings.")
                        .font(Theme.body()).foregroundStyle(Theme.tertiary)
                        .padding(.top, 10)
                        .padding(.bottom, 22)
                } else {
                    EmptyHint(text: "Weigh in a few mornings and the chart appears here.")
                }

                Hairline()
                    .padding(.bottom, 20)

                statsGrid
                    .padding(.bottom, 20)

                Hairline()
                    .padding(.bottom, 20)

                trust
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var kicker: String {
        if let week = s.phaseWeek { return "\(d.phase.title) · week \(week)" }
        return d.phase.title
    }

    private var trendWeight: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Trend weight")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                DottedNumber(text: s.body.trendWeightLb.map(Fmt.lb) ?? "—", number: .trendWeight, font: Theme.large(52), tracking: -52 * 0.04)
                if let change = changeSinceStart, let first = points.first {
                    Text(Fmt.signed(change, 1, suffix: " lb"))
                        .font(.system(size: 18, weight: .bold)).monospacedDigit()
                        .foregroundStyle(changeColor(change))
                    Text("since \(Fmt.shortDate(first.date))").font(.system(size: 18)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private func changeColor(_ change: Double) -> Color {
        switch d.phase {
        case .cut: return change <= 0 ? Theme.good : Theme.behind
        case .leanBulk, .bulk: return change >= 0 ? Theme.good : Theme.behind
        case .recomp, .maintain: return abs(change) <= 1 ? Theme.good : Theme.secondary
        }
    }

    private var rateStatus: (text: String, color: Color) {
        guard let actual = s.actualRatePercentPerWeek else { return ("need more weigh-ins", Theme.secondary) }
        let goal = s.targets.goalRate
        let diff = actual - goal.percentPerWeek
        let goalText = "goal \(Fmt.signed(goal.lbPerWeek, 2))"
        if abs(diff) <= d.rateMissTolerancePercent { return ("\(goalText) · on target", Theme.good) }
        let behind: Bool
        switch d.phase {
        case .cut: behind = diff > 0
        case .leanBulk, .bulk: behind = diff < 0
        case .recomp, .maintain: behind = true
        }
        return ("\(goalText) · \(behind ? "behind" : "ahead")", behind ? Theme.behind : Theme.good)
    }

    private var statsGrid: some View {
        let formulaDiff = s.targets.formulaWeeklyAverage > 0 ? (s.targets.maintenance - s.targets.formulaWeeklyAverage) / s.targets.formulaWeeklyAverage * 100 : 0
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                StatCell(label: "Actual rate",
                         value: AnyView(HStack(alignment: .firstTextBaseline, spacing: 4) {
                            DottedNumber(text: s.actualRateLbPerWeek.map { Fmt.signed($0, 2) } ?? "—", number: .actualRate)
                            Text("lb/wk").font(Theme.body()).foregroundStyle(Theme.secondary)
                         }),
                         caption: rateStatus.text, captionColor: rateStatus.color)
                VerticalHairline().padding(.horizontal, 16)
                StatCell(label: "Observed TDEE",
                         value: AnyView(DottedNumber(text: s.targets.observedTDEE.map(Fmt.int) ?? "—", number: .observedTDEE)),
                         caption: s.targets.observedTDEE == nil ? "needs \(s.observed.requiredDays) days of data" : "intake + weight change")
            }
            .padding(.bottom, 20)
            HStack(alignment: .top, spacing: 0) {
                StatCell(label: "Formula TDEE",
                         value: AnyView(DottedNumber(text: Fmt.int(s.targets.formulaWeeklyAverage), number: .formulaTDEE)),
                         caption: s.targets.observedTDEE == nil ? s.bmr.sourceDescription : "you burn \(Fmt.int(abs(formulaDiff)))% \(formulaDiff >= 0 ? "more" : "less")")
                VerticalHairline().padding(.horizontal, 16)
                StatCell(label: "Maintenance",
                         value: AnyView(DottedNumber(text: Fmt.int(s.targets.maintenance), number: .maintenance)),
                         caption: "blended estimate")
            }
        }
    }

    private var trust: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trust in your data").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                DottedNumber(text: "\(Fmt.int(s.targets.trustPercent))%", number: .trust, font: .system(size: 20, weight: .bold), color: Theme.accent)
            }
            BarView(fraction: s.targets.trust, height: 6, color: Theme.accent)
            Text("\(s.targets.daysLogged) of \(s.targets.windowDays) days logged. Maintenance is \(Fmt.int(s.targets.trustPercent))% observed, \(Fmt.int(100 - s.targets.trustPercent))% formula.")
                .font(Theme.body()).foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
