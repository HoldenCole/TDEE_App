import SwiftUI
import Charts
import TareEngine

/// Bottom sheet for any number: its chart over time, what feeds it, and a jump to the dials behind it.
struct NumberDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let number: NumberID

    @State private var range: ChartRange = .sixWeeks
    @State private var history: [Engine.HistoryPoint] = []
    @State private var loading = true

    private var s: EngineSnapshot { model.snapshot }
    private var d: Dials { model.dials }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.track).frame(width: 40, height: 5).padding(.top, 12).padding(.bottom, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.bottom, 24)
                    chart.padding(.bottom, 22)
                    Hairline().padding(.bottom, 20)
                    Eyebrow("What feeds it").padding(.bottom, 8)
                    feeds
                }
                .padding(.horizontal, Theme.sideMargin)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 12) {
                Button {
                    model.tuneDials(group: number.dialGroup)
                } label: {
                    Text("Tune these dials").font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.pill))
                }
                .buttonStyle(.plain)
                InkButton(title: "Done") { dismiss() }
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.bottom, 12)
        }
        .background(Theme.surface)
        .task(id: range) { await loadHistory() }
    }

    private func loadHistory() async {
        loading = true
        let log = model.log
        let dials = model.dials
        let days = min(range.days, 400)
        let computed = await Task.detached(priority: .userInitiated) {
            Engine.history(log: log, dials: dials, days: days)
        }.value
        history = computed
        loading = false
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(number.title)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(headline.value).largeStyle(52)
                    if let change = headline.change {
                        Text(change.text).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(change.color)
                    }
                }
                Text(headline.units).font(.system(size: 18)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            if showsRange {
                SegmentedPills(options: [(ChartRange.sixWeeks, "6W"), (ChartRange.threeMonths, "3M")], selection: $range)
            }
        }
    }

    private var showsRange: Bool {
        switch number {
        case .bmr, .sensitivity: return false
        default: return true
        }
    }

    private struct Headline {
        var value: String
        var units: String
        var change: (text: String, color: Color)?
    }

    private func changeBadge(_ series: [DatedValue], digits: Int = 0, unit: String = "", goodWhenUp: Bool? = true) -> (text: String, color: Color)? {
        guard let first = series.first, let last = series.last, first.date < last.date else { return nil }
        let delta = last.value - first.value
        let weeks = max(1, Calendar.current.days(from: first.date, to: last.date) / 7)
        let text = "\(Fmt.signed(delta, digits, suffix: unit)) in \(weeks) wk"
        let color: Color
        if let goodWhenUp {
            color = (delta >= 0) == goodWhenUp ? Theme.good : Theme.behind
        } else {
            color = Theme.secondary
        }
        return (text: text, color: color)
    }

    private var headline: Headline {
        let trustLine = "\(Fmt.int(s.targets.trustPercent))% observed, \(Fmt.int(100 - s.targets.trustPercent))% formula"
        switch number {
        case .target:
            return Headline(value: Fmt.int(s.today.calories), units: "kcal · \(s.isTrainingDay ? "training day" : "rest day")", change: changeBadge(history.map { DatedValue(date: $0.date, value: $0.target) }, unit: "", goodWhenUp: nil))
        case .remaining:
            return Headline(value: Fmt.int(s.remainingCalories), units: "kcal left of \(Fmt.int(s.today.calories))", change: nil)
        case .protein:
            return Headline(value: Fmt.int(s.today.proteinG), units: "g target · \(Fmt.int(s.todayLog?.proteinG ?? 0)) eaten", change: nil)
        case .carbs:
            return Headline(value: Fmt.int(s.today.carbsG), units: "g target · \(Fmt.int(s.todayLog?.carbsG ?? 0)) eaten", change: nil)
        case .fat:
            return Headline(value: Fmt.int(s.today.fatG), units: "g target · \(Fmt.int(s.todayLog?.fatG ?? 0)) eaten", change: nil)
        case .water:
            return Headline(value: Fmt.int(s.today.waterOz), units: "oz target", change: nil)
        case .weight:
            return Headline(value: s.body.latestWeighInLb.map(Fmt.lb) ?? "—", units: "lb · trend \(s.body.trendWeightLb.map(Fmt.lb) ?? "—")", change: changeBadge(trendSeries, digits: 1, unit: " lb", goodWhenUp: d.phase.isSurplus ? true : (d.phase.isDeficit ? false : nil)))
        case .trendWeight:
            return Headline(value: s.body.trendWeightLb.map(Fmt.lb) ?? "—", units: "lb · α \(Fmt.dec(d.trendAlpha, 2))", change: changeBadge(trendSeries, digits: 1, unit: " lb", goodWhenUp: d.phase.isSurplus ? true : (d.phase.isDeficit ? false : nil)))
        case .steps:
            return Headline(value: s.todayLog?.steps.map { Fmt.int($0) } ?? "—", units: "today · avg \(Fmt.int(s.activity.stepsPerDay)) over \(d.trustWindowDays) days", change: nil)
        case .maintenance:
            return Headline(value: Fmt.int(s.targets.maintenance), units: "kcal/day · \(trustLine)", change: changeBadge(history.map { DatedValue(date: $0.date, value: $0.maintenance) }, goodWhenUp: nil))
        case .actualRate:
            return Headline(value: s.actualRateLbPerWeek.map { Fmt.signed($0, 2) } ?? "—", units: "lb/wk · goal \(Fmt.signed(s.targets.goalRate.lbPerWeek, 2))", change: nil)
        case .goalRate:
            return Headline(value: Fmt.signed(s.targets.goalRate.lbPerWeek, 2), units: "lb/wk · \(Fmt.signed(s.targets.goalRate.percentPerWeek, 2))% · \(Fmt.signed(s.targets.goalRate.dailyKcal, 0)) kcal/day", change: nil)
        case .observedTDEE:
            return Headline(value: s.targets.observedTDEE.map(Fmt.int) ?? "—", units: "kcal/day from \(s.observed.daysWithCalories) logged days", change: changeBadge(history.compactMap { p in p.observedTDEE.map { DatedValue(date: p.date, value: $0) } }, goodWhenUp: nil))
        case .formulaTDEE:
            return Headline(value: Fmt.int(s.targets.formulaWeeklyAverage), units: "kcal/day · \(s.bmr.sourceDescription)", change: nil)
        case .trust:
            return Headline(value: "\(Fmt.int(s.targets.trustPercent))%", units: "\(s.targets.daysLogged) of \(s.targets.windowDays) days · max \(Fmt.int(d.maxTrustPercent))%", change: nil)
        case .bmr:
            return Headline(value: Fmt.int(s.bmr.value), units: "kcal/day · \(s.bmr.sourceDescription)", change: nil)
        case .bodyFat:
            return Headline(value: s.body.bodyFatPercent.map { Fmt.dec($0, 1) + "%" } ?? "—", units: "body fat · \(d.bodyFatSource.rawValue)", change: nil)
        case .leanMass:
            return Headline(value: s.body.leanMassLb.map(Fmt.lb) ?? "—", units: "lb lean mass", change: nil)
        case .sets(let m):
            let weeks = LiftAnalytics.weeklyHardSets(sets: model.liftSets, map: model.muscleMap, weeks: 1, today: Date())
            let thisWeek = weeks.last?.sets[m] ?? 0
            return Headline(value: Fmt.dec(thisWeek, 0), units: "hard sets this week · target \(d.hardSetsTargetPerWeek)", change: nil)
        case .e1rm(let ex):
            let strength = LiftAnalytics.strength(sets: model.liftSets).first { $0.exercise == ex }
            let since = range.start()
            let change = strength?.change(since: since)
            return Headline(value: strength?.latest.map(Fmt.int) ?? "—", units: "lb estimated 1RM · Epley", change: change.map { (text: Fmt.signed($0, 0, suffix: " lb"), color: $0 >= 0 ? Theme.good : Theme.behind) })
        case .sensitivity(let key):
            let spec = DialCatalog.spec(for: key, in: d)
            let kcal = model.sensitivity(for: key)
            return Headline(value: Fmt.signed(kcal, 0), units: "kcal on today's target from \(spec?.title ?? key.rawValue)", change: nil)
        }
    }

    private var trendSeries: [DatedValue] {
        let start = range.start()
        return s.trend.filter { $0.date >= start }.map { DatedValue(date: $0.date, value: $0.trendLb) }
    }

    private var markers: [ChartMarker] {
        model.chartMarkers(from: range.start()).map(ChartMarker.init(change:))
    }

    private var phases: [PhaseSpan] {
        model.phaseSpans(from: range.start(), to: Date())
    }

    private func logSeries(_ keyPath: KeyPath<DayInput, Double?>) -> [DatedValue] {
        let start = range.start()
        return model.log.filter { $0.date >= start }.compactMap { day in day[keyPath: keyPath].map { DatedValue(date: day.date, value: $0) } }
    }

    // MARK: Chart

    @ViewBuilder
    private var chart: some View {
        switch number {
        case .target, .remaining:
            LineSeriesChart(series: history.map { DatedValue(date: $0.date, value: $0.target) }, bars: history.compactMap { p in p.eaten.map { DatedValue(date: p.date, value: $0) } }, markers: markers, phases: phases)
            Text("Target over time, with what you ate as bars.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .protein:
            macroChart(eaten: logSeries(\.proteinG), target: s.today.proteinG)
        case .carbs:
            macroChart(eaten: logSeries(\.carbsG), target: s.today.carbsG)
        case .fat:
            macroChart(eaten: logSeries(\.fatG), target: s.today.fatG)
        case .water:
            macroChart(eaten: logSeries(\.waterOz), target: s.today.waterOz)
        case .weight, .trendWeight:
            WeightChart(points: s.trend.filter { $0.date >= range.start() }, markers: markers, phases: phases)
            Text("Dots are daily weigh-ins. The line ignores water and sodium swings.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .steps:
            let steps = model.log.filter { $0.date >= range.start() }.compactMap { day in day.steps.map { DatedValue(date: day.date, value: Double($0)) } }
            LineSeriesChart(series: [], dashed: steps.map { DatedValue(date: $0.date, value: s.activity.stepsPerDay) }, bars: steps)
            Text("Daily steps, with your \(d.trustWindowDays)-day average dashed.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .maintenance:
            LineSeriesChart(series: history.compactMap { p in p.observedTDEE.map { DatedValue(date: p.date, value: $0) } }, secondary: history.map { DatedValue(date: $0.date, value: $0.maintenance) }, dashed: history.map { DatedValue(date: $0.date, value: $0.formulaTDEE) }, markers: markers, phases: phases)
            Text("Observed TDEE in accent, the blended value as the faint line, formula TDEE dashed.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .actualRate:
            LineSeriesChart(series: history.compactMap { p in p.actualRateLbPerWeek.map { DatedValue(date: p.date, value: $0) } }, dashed: history.map { DatedValue(date: $0.date, value: $0.goalRateLbPerWeek) }, yDigits: 2)
            Text("Weekly rate from the trend-weight fit, against the goal rate dashed.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .goalRate:
            LineSeriesChart(series: history.map { DatedValue(date: $0.date, value: $0.goalRateLbPerWeek) }, markers: markers, phases: phases, yDigits: 2)
        case .observedTDEE:
            LineSeriesChart(series: history.compactMap { p in p.observedTDEE.map { DatedValue(date: p.date, value: $0) } })
        case .formulaTDEE:
            LineSeriesChart(series: history.map { DatedValue(date: $0.date, value: $0.formulaTDEE) }, markers: markers)
        case .trust:
            LineSeriesChart(series: history.map { DatedValue(date: $0.date, value: $0.trust * 100) })
            Text("Share of the observed TDEE in the blend, as days get logged.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .bmr:
            VStack(alignment: .leading, spacing: 10) {
                ForEach(BMRFormula.allCases.filter { s.bmr.byFormula[$0] != nil }, id: \.self) { f in
                    HStack {
                        Text(f.shortName).font(Theme.body()).foregroundStyle(Theme.secondary)
                        Spacer()
                        Text(Fmt.int(s.bmr.byFormula[f] ?? 0)).font(Theme.body(.semibold)).monospacedDigit().foregroundStyle(s.bmr.used.contains(f) ? Theme.ink : Theme.tertiary)
                    }
                }
            }
        case .bodyFat:
            LineSeriesChart(series: logSeries(\.bodyFatPercent), yDigits: 1)
        case .leanMass:
            LineSeriesChart(series: logSeries(\.leanMassLb), yDigits: 1)
        case .sets(let m):
            let weeks = LiftAnalytics.weeklyHardSets(sets: model.liftSets, map: model.muscleMap, weeks: range == .sixWeeks ? 8 : 12, today: Date())
            LineSeriesChart(series: [], dashed: weeks.map { DatedValue(date: $0.weekEnd, value: Double(d.hardSetsTargetPerWeek)) }, bars: weeks.map { DatedValue(date: $0.weekEnd, value: $0.sets[m] ?? 0) })
            Text("Hard sets per week. Warm-ups excluded; secondary muscles count half.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .e1rm(let ex):
            let sessions = LiftAnalytics.strength(sets: model.liftSets).first { $0.exercise == ex }?.sessions.filter { $0.date >= range.start() } ?? []
            LineSeriesChart(series: sessions.map { DatedValue(date: $0.date, value: $0.e1RM) })
            Text("Best set of 10 reps or fewer each session, Epley formula.").captionStyle(Theme.tertiary).padding(.top, 8)
        case .sensitivity(let key):
            sensitivityChart(key)
        }
    }

    private func macroChart(eaten: [DatedValue], target: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LineSeriesChart(series: [], dashed: eaten.map { DatedValue(date: $0.date, value: target) }, bars: eaten)
            Text("Daily grams as bars, today's target dashed.").captionStyle(Theme.tertiary)
        }
    }

    private func sensitivityChart(_ key: DialKey) -> some View {
        let curve = Engine.sensitivityCurve(log: model.log, dials: d, key: key, samples: 16)
        let current = d.value(for: key).doubleValue ?? 0
        let spec = DialCatalog.spec(for: key, in: d)
        return VStack(alignment: .leading, spacing: 8) {
            if curve.isEmpty {
                Text("This dial isn't a slider, so there's no curve to draw. Its effect on today's target is \(Fmt.signed(model.sensitivity(for: key), 0)) kcal.").font(Theme.body()).foregroundStyle(Theme.secondary)
            } else {
                Chart {
                    ForEach(Array(curve.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Dial", p.value), y: .value("Target", p.target))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    RuleMark(x: .value("Current", current))
                        .foregroundStyle(Theme.behindBar)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("now").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.behind)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel().font(Theme.axis()).foregroundStyle(Theme.tertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel().font(Theme.axis()).foregroundStyle(Theme.tertiary)
                    }
                }
                .frame(height: 200)
                Text("Today's target as \(spec?.title.lowercased() ?? "this dial") moves across its range.").captionStyle(Theme.tertiary)
            }
        }
    }

    // MARK: Feeds

    private struct Feed: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var number: NumberID? = nil
        var dialGroup: DialGroup? = nil
    }

    private var feedRows: [Feed] {
        let t = s.targets
        switch number {
        case .target, .remaining:
            return [
                Feed(label: "Maintenance", value: "\(Fmt.int(t.maintenance)) kcal", number: .maintenance),
                Feed(label: "Goal rate", value: "\(Fmt.signed(t.goalRate.dailyKcal, 0)) kcal/day", number: .goalRate),
                Feed(label: "Cycling", value: d.cyclingEnabled ? "\(Fmt.signed(t.cyclingGap, 0)) kcal gap" : "off", dialGroup: .cycling),
                Feed(label: "Weekday offset", value: "\(Fmt.signed(d.weekdayOffset(forWeekday: Calendar.current.component(.weekday, from: Date())), 0)) kcal", dialGroup: .cycling),
                Feed(label: "Rounding", value: "nearest \(d.roundingKcal)", dialGroup: .display),
            ]
        case .protein:
            return [
                Feed(label: "Protein dial", value: "\(Fmt.dec(d.proteinGramsPerLb, 2)) g/lb", dialGroup: .macros),
                Feed(label: "Basis", value: d.proteinBasis.rawValue, dialGroup: .macros),
                Feed(label: "Weight used", value: "\(Fmt.lb(s.body.weightUsedLb)) lb", number: .weight),
            ]
        case .carbs:
            return [
                Feed(label: "Target", value: "\(Fmt.int(s.today.calories)) kcal", number: .target),
                Feed(label: "Protein", value: "\(Fmt.int(s.today.proteinG)) g", number: .protein),
                Feed(label: "Fat", value: "\(Fmt.int(s.today.fatG)) g", number: .fat),
                Feed(label: "Carb floor", value: "\(Fmt.int(d.carbFloorGrams)) g", dialGroup: .macros),
            ]
        case .fat:
            return [
                Feed(label: d.fatMode == .gramsPerLb ? "Fat floor" : "Fat share", value: d.fatMode == .gramsPerLb ? "\(Fmt.dec(d.fatGramsPerLb, 2)) g/lb" : "\(Fmt.int(d.fatPercentOfCalories))% kcal", dialGroup: .macros),
                Feed(label: "Weight used", value: "\(Fmt.lb(s.body.weightUsedLb)) lb", number: .weight),
            ]
        case .water:
            return [
                Feed(label: "Per lb", value: "\(Fmt.dec(d.waterOzPerLb, 2)) oz", dialGroup: .display),
                Feed(label: "Per training hour", value: "\(Fmt.int(d.waterOzPerTrainingHour)) oz", dialGroup: .display),
            ]
        case .weight, .trendWeight:
            return [
                Feed(label: "Weigh-ins in range", value: "\(s.trend.filter { $0.date >= range.start() }.count)"),
                Feed(label: "Smoothing α", value: Fmt.dec(d.trendAlpha, 2), dialGroup: .body),
                Feed(label: "Outlier filter", value: d.outlierThresholdLb.map { "\(Fmt.dec($0, 0)) lb" } ?? "off", dialGroup: .body),
                Feed(label: "Weight used", value: d.weightSource.rawValue, dialGroup: .body),
            ]
        case .steps:
            return [
                Feed(label: "Source", value: "Apple Health"),
                Feed(label: "Step cost", value: "\(DialFormat.number(d.stepCostKcalPerStepPerKg, step: 0.00001)) kcal/step/kg", dialGroup: .activity),
                Feed(label: "Burn at average", value: "\(Fmt.int(s.formula.steps)) kcal/day", number: .formulaTDEE),
            ]
        case .maintenance:
            return [
                Feed(label: "Avg intake, \(d.trustWindowDays) days", value: s.observed.meanIntake.map { "\(Fmt.int($0)) kcal" } ?? "—"),
                Feed(label: "Weight slope × \(Fmt.int(d.kcalPerLb))", value: s.observed.weightChangeKcal.map { "\(Fmt.signed(-$0, 0)) kcal" } ?? "—"),
                Feed(label: "Trust", value: "\(Fmt.int(t.trustPercent))% · window \(d.trustWindowDays) d", number: .trust),
                Feed(label: "Formula, \(s.bmr.sourceDescription)", value: Fmt.int(t.formulaWeeklyAverage), number: .formulaTDEE),
            ]
        case .actualRate:
            return [
                Feed(label: "Trend weight slope", value: s.actualRateLbPerWeek.map { "\(Fmt.signed($0 / 7, 3)) lb/day" } ?? "—", number: .trendWeight),
                Feed(label: "Window", value: "\(d.trustWindowDays) days", dialGroup: .adaptive),
                Feed(label: "Goal", value: Fmt.rate(t.goalRate.lbPerWeek), number: .goalRate),
            ]
        case .goalRate:
            return [
                Feed(label: "Rate mode", value: d.rateMode.rawValue, dialGroup: .goal),
                Feed(label: "Rate", value: "\(Fmt.signed(d.ratePercentPerWeek, 2))%/wk", dialGroup: .goal),
                Feed(label: "Weight used", value: "\(Fmt.lb(s.body.weightUsedLb)) lb", number: .weight),
                Feed(label: "Energy per lb", value: "\(Fmt.int(d.kcalPerLb)) kcal", dialGroup: .adaptive),
            ]
        case .observedTDEE:
            return [
                Feed(label: "Mean intake", value: s.observed.meanIntake.map { "\(Fmt.int($0)) kcal" } ?? "—"),
                Feed(label: "Slope", value: s.observed.slopeLbPerDay.map { "\(Fmt.signed($0 * 7, 2)) lb/wk" } ?? "—", number: .actualRate),
                Feed(label: "Days with calories", value: "\(s.observed.daysWithCalories) of \(d.trustWindowDays)", number: .trust),
                Feed(label: "Days with weigh-ins", value: "\(s.observed.daysWithWeight)"),
                Feed(label: "Incomplete days", value: d.incompleteFoodDays.rawValue, dialGroup: .adaptive),
            ]
        case .formulaTDEE:
            return [
                Feed(label: "BMR", value: Fmt.int(s.bmr.value), number: .bmr),
                Feed(label: "Daily living", value: "\(Fmt.int(s.formula.dailyLiving)) kcal", dialGroup: .activity),
                Feed(label: "Steps", value: "\(Fmt.int(s.formula.steps)) kcal", number: .steps),
                Feed(label: "Lifting, per session", value: "\(Fmt.int(s.formula.lift)) kcal", dialGroup: .activity),
                Feed(label: "Cardio, per day", value: "\(Fmt.int(s.formula.cardio)) kcal", dialGroup: .activity),
                Feed(label: "Digestion", value: "\(Fmt.int(s.formula.tef)) kcal", dialGroup: .digestion),
                Feed(label: "Lift days per week", value: Fmt.dec(t.liftDaysPerWeek, 1), dialGroup: .cycling),
            ]
        case .trust:
            return [
                Feed(label: "Days logged", value: "\(t.daysLogged) of \(t.windowDays)"),
                Feed(label: "Max trust", value: "\(Fmt.int(d.maxTrustPercent))%", dialGroup: .adaptive),
                Feed(label: "Days before trusting", value: "\(d.minDaysBeforeTrust)", dialGroup: .adaptive),
            ]
        case .bmr:
            return [
                Feed(label: "Weight", value: "\(Fmt.lb(s.body.weightUsedLb)) lb", number: .weight),
                Feed(label: "Height", value: d.heightCm.map(Fmt.heightFeetInches) ?? "not set", dialGroup: .profile),
                Feed(label: "Age", value: s.body.ageYears.map { "\(Int($0))" } ?? "not set", dialGroup: .profile),
                Feed(label: "Lean mass", value: s.body.leanMassLb.map { "\(Fmt.lb($0)) lb" } ?? "unknown", number: .leanMass),
                Feed(label: "Adjustment", value: "\(Fmt.signed(d.bmrAdjustmentPercent, 0))%", dialGroup: .bmr),
            ]
        case .bodyFat:
            return [
                Feed(label: "Source", value: d.bodyFatSource.rawValue, dialGroup: .body),
                Feed(label: "Lean mass", value: s.body.leanMassLb.map { "\(Fmt.lb($0)) lb" } ?? "—", number: .leanMass),
            ]
        case .leanMass:
            return [
                Feed(label: "Weight used", value: "\(Fmt.lb(s.body.weightUsedLb)) lb", number: .weight),
                Feed(label: "Body fat", value: s.body.bodyFatPercent.map { Fmt.dec($0, 1) + "%" } ?? "—", number: .bodyFat),
            ]
        case .sets(let m):
            return LiftAnalytics.exercises(for: m, in: model.liftSets, map: model.muscleMap).prefix(5).map { ex in
                let primary = model.muscleMap.lookup(ex)?.primary == m
                return Feed(label: ex, value: primary ? "primary" : "secondary, ½", number: .e1rm(ex))
            } + [Feed(label: "Target", value: "\(d.hardSetsTargetPerWeek) sets/wk", dialGroup: .coach)]
        case .e1rm(let ex):
            let strength = LiftAnalytics.strength(sets: model.liftSets).first { $0.exercise == ex }
            let sessions = Array((strength?.sessions ?? []).suffix(5))
            var relative = "—"
            if let w = s.body.trendWeightLb, let latest = strength?.latest, w > 0 {
                relative = Fmt.dec(latest / w, 2) + "× bodyweight"
            }
            var rows: [Feed] = sessions.reversed().map { Feed(label: Fmt.shortDate($0.date), value: "\(Fmt.int($0.bestSetWeightLb)) × \($0.bestSetReps) → \(Fmt.int($0.e1RM))") }
            rows.append(Feed(label: "Relative strength", value: relative))
            return rows
        case .sensitivity(let key):
            let spec = DialCatalog.spec(for: key, in: d)
            return [
                Feed(label: spec?.title ?? key.rawValue, value: d.value(for: key).compactDescription, dialGroup: spec?.group),
                Feed(label: "Default", value: spec?.defaultValue.compactDescription ?? "—"),
                Feed(label: "Today's target", value: "\(Fmt.int(s.today.calories)) kcal", number: .target),
            ]
        }
    }

    private var feeds: some View {
        VStack(spacing: 0) {
            ForEach(feedRows) { row in
                HStack {
                    Text(row.label).font(.system(size: 17)).foregroundStyle(Theme.secondary)
                    Spacer()
                    if let n = row.number {
                        DottedNumber(text: row.value, number: n, font: .system(size: 17, weight: .bold))
                    } else if let g = row.dialGroup {
                        Button { model.tuneDials(group: g) } label: {
                            Text(row.value).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                                .underline(true, pattern: .dot, color: Theme.accent)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(row.value).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                }
                .padding(.vertical, 11)
            }
        }
    }
}
