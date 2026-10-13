import Foundation

public enum CoachRule: String, Codable, CaseIterable, Sendable {
    case rateOffTarget, incompleteLogging, strengthDropping, longCut, undertrainedMuscle, proteinShort, stepsDrifting, bulkOvershoot

    public var title: String {
        switch self {
        case .rateOffTarget: return "Rate off target"
        case .incompleteLogging: return "Incomplete logging"
        case .strengthDropping: return "Strength dropping"
        case .longCut: return "Long cut"
        case .undertrainedMuscle: return "Undertrained muscle"
        case .proteinShort: return "Protein short"
        case .stepsDrifting: return "Steps drifting"
        case .bulkOvershoot: return "Bulk overshoot"
        }
    }
}

public struct CoachMathRow: Codable, Equatable, Sendable {
    public var label: String
    public var value: String
    /// When set, the value opens the number-detail sheet for this number ID.
    public var numberID: String?
    public var highlighted: Bool

    public init(_ label: String, _ value: String, numberID: String? = nil, highlighted: Bool = false) {
        self.label = label
        self.value = value
        self.numberID = numberID
        self.highlighted = highlighted
    }
}

public struct CoachPoint: Codable, Equatable, Sendable {
    public var date: Date
    public var value: Double
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public enum CoachSeriesStyle: String, Codable, Sendable {
    case line, dashed, bars
}

public struct CoachSeries: Codable, Equatable, Sendable {
    public var name: String
    public var style: CoachSeriesStyle
    public var points: [CoachPoint]
    public init(name: String, style: CoachSeriesStyle, points: [CoachPoint]) {
        self.name = name
        self.style = style
        self.points = points
    }
}

public struct CoachChart: Codable, Equatable, Sendable {
    public var title: String
    public var caption: String
    public var series: [CoachSeries]
    public var unit: String
    public init(title: String, caption: String, unit: String, series: [CoachSeries]) {
        self.title = title
        self.caption = caption
        self.unit = unit
        self.series = series
    }
}

/// One dial change the coach wants to make.
public struct DialProposal: Codable, Equatable, Sendable {
    public var key: DialKey
    public var oldValue: DialValue
    public var newValue: DialValue
    public init(key: DialKey, oldValue: DialValue, newValue: DialValue) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public struct CoachRecommendation: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var rule: CoachRule
    public var date: Date
    public var headline: String
    public var reason: String
    public var math: [CoachMathRow]
    public var proposals: [DialProposal]
    /// The calorie change behind the proposal, when there is one. Drives "Accept +130" and Edit amount.
    public var kcalChange: Double?
    public var ifAccepted: String
    public var chart: CoachChart?
    /// True for the incomplete-logging rule: other calorie changes wait.
    public var holdsCalorieChanges: Bool

    public init(id: UUID = UUID(), rule: CoachRule, date: Date, headline: String, reason: String, math: [CoachMathRow] = [], proposals: [DialProposal] = [], kcalChange: Double? = nil, ifAccepted: String, chart: CoachChart? = nil, holdsCalorieChanges: Bool = false) {
        self.id = id
        self.rule = rule
        self.date = date
        self.headline = headline
        self.reason = reason
        self.math = math
        self.proposals = proposals
        self.kcalChange = kcalChange
        self.ifAccepted = ifAccepted
        self.chart = chart
        self.holdsCalorieChanges = holdsCalorieChanges
    }

    public var hasProposal: Bool { !proposals.isEmpty }
}

public struct CoachContext: Sendable {
    public var log: [DayInput]
    public var liftSets: [LiftSetInput]
    public var muscleMap: MuscleMap
    /// How many check-ins in a row the rate has already missed, before this one.
    public var previousRateMisses: Int

    public init(log: [DayInput], liftSets: [LiftSetInput] = [], muscleMap: MuscleMap = MuscleMap(), previousRateMisses: Int = 0) {
        self.log = log
        self.liftSets = liftSets
        self.muscleMap = muscleMap
        self.previousRateMisses = previousRateMisses
    }
}

public struct CoachReport: Equatable, Sendable {
    public var recommendations: [CoachRecommendation]
    /// Whether the rate missed at this check-in; the app stores the streak for next time.
    public var rateMissedThisCheckIn: Bool
    public var consecutiveRateMisses: Int
}

public enum Coach {

    /// True on the check-in weekday when no check-in has run yet that day.
    public static func isCheckInDue(lastCheckIn: Date?, today: Date, dials: Dials, calendar: Calendar = .current) -> Bool {
        guard calendar.component(.weekday, from: today) == dials.coachCheckInWeekday else { return false }
        if let last = lastCheckIn, calendar.isDate(last, inSameDayAs: today) { return false }
        return true
    }

    /// Runs every rule against the week that just ended.
    public static func evaluate(context: CoachContext, dials: Dials, today: Date = Date(), calendar: Calendar = .current) -> CoachReport {
        let snapshot = Engine.compute(log: context.log, dials: dials, today: today, calendar: calendar)
        var recs: [CoachRecommendation] = []

        let hold = incompleteLogging(context: context, snapshot: snapshot, dials: dials, today: today, calendar: calendar)
        if let hold { recs.append(hold) }
        let holding = hold != nil

        var rateMissed = false
        var misses = 0
        if let (rec, missed) = rateOffTarget(context: context, snapshot: snapshot, dials: dials, today: today, calendar: calendar) {
            rateMissed = missed
            misses = missed ? context.previousRateMisses + 1 : 0
            if let rec, !holding { recs.append(rec) }
        }

        if !holding, let rec = strengthDropping(context: context, snapshot: snapshot, dials: dials, today: today, calendar: calendar) { recs.append(rec) }
        if let rec = longCut(snapshot: snapshot, dials: dials, today: today, calendar: calendar) { recs.append(rec) }
        if let rec = bulkOvershoot(snapshot: snapshot, dials: dials, today: today) { recs.append(rec) }
        if let rec = undertrainedMuscle(context: context, dials: dials, today: today, calendar: calendar) { recs.append(rec) }
        if let rec = proteinShort(context: context, snapshot: snapshot, dials: dials, today: today, calendar: calendar) { recs.append(rec) }
        if let rec = stepsDrifting(context: context, snapshot: snapshot, dials: dials, today: today, calendar: calendar) { recs.append(rec) }

        return CoachReport(recommendations: recs, rateMissedThisCheckIn: rateMissed, consecutiveRateMisses: misses)
    }

    // MARK: Rules

    static func lastWeek(_ log: [DayInput], today: Date, calendar: Calendar) -> [DayInput] {
        log.filter { let d = calendar.days(from: $0.date, to: today); return d >= 1 && d <= 7 }
    }

    static func incompleteLogging(context: CoachContext, snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        let week = lastWeek(context.log, today: today, calendar: calendar)
        let logged = week.filter { $0.countsForIntake(policy: dials.incompleteFoodDays) }.count
        guard logged < dials.minLoggedDaysPerWeek else { return nil }
        return CoachRecommendation(
            rule: .incompleteLogging,
            date: today,
            headline: "Hold calorie changes this week",
            reason: "Only \(logged) of 7 days had food logged. The coach needs \(dials.minLoggedDaysPerWeek) to trust the week.",
            math: [
                CoachMathRow("Days with food logged", "\(logged) of 7", numberID: "trust"),
                CoachMathRow("Needed", "\(dials.minLoggedDaysPerWeek)"),
            ],
            ifAccepted: "Nothing changes. Log every day this week and the coach will look again next check-in.",
            chart: CoachChart(title: "Logged days", caption: "Calories logged each day last week.", unit: "kcal", series: [
                CoachSeries(name: "Eaten", style: .bars, points: week.sorted { $0.date < $1.date }.map { CoachPoint(date: $0.date, value: $0.calories ?? 0) }),
            ]),
            holdsCalorieChanges: true
        )
    }

    static func rateOffTarget(context: CoachContext, snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> (CoachRecommendation?, Bool)? {
        guard !snapshot.targets.goalRate.isDietBreak else { return nil }
        guard let actualLb = snapshot.actualRateLbPerWeek, let actualPct = snapshot.actualRatePercentPerWeek, snapshot.observed.daysWithWeight >= dials.minDaysBeforeTrust else { return nil }
        let goal = snapshot.targets.goalRate
        let missPct = actualPct - goal.percentPercentSafe
        let missed = abs(missPct) > dials.rateMissTolerancePercent
        let misses = missed ? context.previousRateMisses + 1 : 0
        guard missed, misses >= dials.rateMissCheckIns else { return (nil, missed) }

        let rawKcal = (goal.lbPerWeek - actualLb) * dials.kcalPerLb / 7
        let capped = max(-dials.coachMaxChangeKcal, min(dials.coachMaxChangeKcal, rawKcal))
        let kcal = Units.round(capped, toNearest: max(dials.roundingKcal, 5))
        guard abs(kcal) >= 10 else { return (nil, missed) }

        let newLb = goal.lbPerWeek + kcal * 7 / dials.kcalPerLb
        var proposals: [DialProposal] = []
        if let (key, value) = GoalRate.dialValue(forLbPerWeek: newLb, dials: dials, weightLb: snapshot.body.weightUsedLb) {
            proposals.append(DialProposal(key: key, oldValue: dials.value(for: key), newValue: value))
        }

        let direction = kcal > 0 ? "Raise" : "Lower"
        let verb = actualLb >= 0 ? "Gaining" : "Losing"
        let weeks = max(1, dials.trustWindowDays / 7)
        let newTrain = snapshot.targets.training.calories + kcal
        let newRest = snapshot.targets.rest.calories + kcal
        let chart = weightVsGoalChart(snapshot: snapshot, dials: dials, today: today, calendar: calendar)

        let rec = CoachRecommendation(
            rule: .rateOffTarget,
            date: today,
            headline: "\(direction) your target by \(Int(abs(kcal))) kcal",
            reason: "\(verb) \(Format.signed(actualLb, 2)) lb/wk for \(Format.weeks(weeks)) against a \(Format.signed(goal.lbPerWeek, 2)) goal. Tap for the chart and the math.",
            math: [
                CoachMathRow("Goal rate", "\(Format.signed(goal.lbPerWeek, 2)) lb/wk", numberID: "goalRate"),
                CoachMathRow("Actual, \(dials.trustWindowDays)-day fit", "\(Format.signed(actualLb, 2)) lb/wk", numberID: "actualRate"),
                CoachMathRow("Gap × \(Format.int(dials.kcalPerLb)) ÷ 7", "\(Format.int(abs(rawKcal))) kcal/day"),
                CoachMathRow("Rounded, capped at \(Int(dials.coachMaxChangeKcal))", "\(Format.signed(kcal, 0)) kcal/day", highlighted: true),
            ],
            proposals: proposals,
            kcalChange: kcal,
            ifAccepted: "Training days go to \(Format.int(newTrain)), rest days to \(Format.int(newRest)). Carbs take the \(kcal > 0 ? "extra" : "cut"). The change is logged and marked on your Trend chart; the coach checks again next \(Format.weekdayName(dials.coachCheckInWeekday, calendar: calendar)).",
            chart: chart
        )
        return (rec, missed)
    }

    static func weightVsGoalChart(snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachChart {
        let n = dials.trustWindowDays
        let trend = snapshot.trend.filter { calendar.days(from: $0.date, to: today) < n }
        let start = trend.first?.date ?? today
        let startWeight = trend.first?.trendLb ?? snapshot.body.weightUsedLb
        let path = Engine.goalPath(from: start, startWeightLb: startWeight, lbPerWeek: snapshot.targets.goalRate.lbPerWeek, through: today, calendar: calendar)
        let gap = (path.last?.weightLb ?? startWeight) - (trend.last?.trendLb ?? startWeight)
        let weeks = max(1, n / 7)
        return CoachChart(
            title: "Weight vs goal path",
            caption: "\(Format.weeks(weeks).capitalized) of trend weight against where the plan says you'd be. \(Format.number(abs(gap), 1)) lb \(gap > 0 ? "behind" : "ahead").",
            unit: "lb",
            series: [
                CoachSeries(name: "you \(Format.signed(snapshot.actualRateLbPerWeek ?? 0, 2)) lb/wk", style: .line, points: trend.map { CoachPoint(date: $0.date, value: $0.trendLb) }),
                CoachSeries(name: "goal path \(Format.signed(snapshot.targets.goalRate.lbPerWeek, 2)) lb/wk", style: .dashed, points: path.map { CoachPoint(date: $0.date, value: $0.weightLb) }),
            ]
        )
    }

    static func strengthDropping(context: CoachContext, snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        guard dials.phase == .cut else { return nil }
        let strength = LiftAnalytics.unlockedExercises(LiftAnalytics.strength(sets: context.liftSets, calendar: calendar), dials: dials)
        guard let since = calendar.date(byAdding: .day, value: -dials.strengthDropWeeks * 7, to: calendar.startOfDay(for: today)) else { return nil }
        var dropping: [(ExerciseStrength, Double)] = []
        for ex in strength {
            guard let last = ex.sessions.last, calendar.days(from: last.date, to: today) <= 14, let pct = ex.percentChange(since: since) else { continue }
            if pct <= -dials.strengthDropPercent { dropping.append((ex, pct)) }
        }
        guard dropping.count >= dials.strengthDropLifts else { return nil }

        let w = snapshot.body.weightUsedLb
        let currentLb = snapshot.targets.goalRate.lbPerWeek
        let newLb = currentLb + dials.strengthSlowRatePercent / 100 * w
        var proposals: [DialProposal] = []
        if let (key, value) = GoalRate.dialValue(forLbPerWeek: newLb, dials: dials, weightLb: w) {
            proposals.append(DialProposal(key: key, oldValue: dials.value(for: key), newValue: value))
        }
        let kcal = Units.round((newLb - currentLb) * dials.kcalPerLb / 7, toNearest: max(dials.roundingKcal, 5))
        let names = dropping.prefix(3).map { $0.0.exercise }
        let range = dropping.map { abs($0.1) }
        let series = dropping.prefix(4).map { ex, _ in
            CoachSeries(name: ex.exercise, style: .line, points: ex.sessions.filter { $0.date >= since }.map { CoachPoint(date: $0.date, value: $0.e1RM) })
        }
        return CoachRecommendation(
            rule: .strengthDropping,
            date: today,
            headline: "Slow the cut by \(Format.number(dials.strengthSlowRatePercent, 2))%/wk",
            reason: "\(Format.list(names)) \(names.count == 1 ? "is" : "are") down \(Format.int(range.min() ?? 0))–\(Format.int(range.max() ?? 0))% over \(dials.strengthDropWeeks) weeks. A slower deficit, or a 1–2 week maintenance break, usually brings it back.",
            math: dropping.map { CoachMathRow($0.0.exercise, "\(Format.signed($0.1, 1))%", numberID: "e1rm:\($0.0.exercise)") } + [
                CoachMathRow("Rate now", "\(Format.signed(snapshot.targets.goalRate.percentPercentSafe, 2))%/wk", numberID: "goalRate"),
                CoachMathRow("Rate if accepted", "\(Format.signed(snapshot.targets.goalRate.percentPercentSafe + dials.strengthSlowRatePercent, 2))%/wk", highlighted: true),
            ],
            proposals: proposals,
            kcalChange: kcal,
            ifAccepted: "The deficit eases by about \(Format.int(kcal)) kcal/day. If you'd rather take a maintenance break, set the phase to Maintain on Plan for 1–2 weeks instead.",
            chart: CoachChart(title: "Estimated 1RM", caption: "Best set each session, Epley formula.", unit: "lb", series: series)
        )
    }

    static func longCut(snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        guard dials.phase == .cut, let start = dials.phaseStartDate else { return nil }
        let weeks = calendar.days(from: start, to: today) / 7
        guard weeks > dials.longCutWeeks else { return nil }
        return CoachRecommendation(
            rule: .longCut,
            date: today,
            headline: "Take a maintenance phase",
            reason: "You've been cutting for \(weeks) weeks, past your \(dials.longCutWeeks)-week limit. A few weeks at maintenance restores training quality and makes the next cut easier.",
            math: [
                CoachMathRow("Weeks in deficit", "\(weeks)"),
                CoachMathRow("Your limit", "\(dials.longCutWeeks)"),
                CoachMathRow("Maintenance", "\(Format.int(snapshot.targets.maintenance)) kcal", numberID: "maintenance", highlighted: true),
            ],
            proposals: [
                DialProposal(key: .phase, oldValue: dials.value(for: .phase), newValue: .choice(Phase.maintain.rawValue)),
                DialProposal(key: .ratePercentPerWeek, oldValue: dials.value(for: .ratePercentPerWeek), newValue: .number(0)),
            ],
            kcalChange: -snapshot.targets.goalRate.dailyKcal,
            ifAccepted: "The phase switches to Maintain and the rate to 0, so the target rises to about \(Format.int(snapshot.targets.maintenance)) kcal. Switch back to Cut on Plan when you're ready.",
            chart: weightVsGoalChart(snapshot: snapshot, dials: dials, today: today, calendar: calendar)
        )
    }

    static func bulkOvershoot(snapshot: EngineSnapshot, dials: Dials, today: Date) -> CoachRecommendation? {
        guard dials.phase.isSurplus, let bf = snapshot.body.bodyFatPercent, bf > dials.bodyFatCeilingPercent else { return nil }
        return CoachRecommendation(
            rule: .bulkOvershoot,
            date: today,
            headline: "Switch to a cut",
            reason: "Body fat is \(Format.number(bf, 1))%, above your \(Format.number(dials.bodyFatCeilingPercent, 1))% ceiling. More surplus from here mostly adds fat.",
            math: [
                CoachMathRow("Body fat", "\(Format.number(bf, 1))%", numberID: "bodyFat"),
                CoachMathRow("Ceiling", "\(Format.number(dials.bodyFatCeilingPercent, 1))%"),
            ],
            proposals: [
                DialProposal(key: .phase, oldValue: dials.value(for: .phase), newValue: .choice(Phase.cut.rawValue)),
                DialProposal(key: .ratePercentPerWeek, oldValue: dials.value(for: .ratePercentPerWeek), newValue: .number(Phase.cut.defaultRatePercent)),
            ],
            kcalChange: (Phase.cut.defaultRatePercent / 100 * snapshot.body.weightUsedLb * dials.kcalPerLb / 7) - snapshot.targets.goalRate.dailyKcal,
            ifAccepted: "The phase switches to Cut at \(Format.number(Phase.cut.defaultRatePercent, 2))%/wk. Adjust the rate on Plan if you want a gentler start."
        )
    }

    static func undertrainedMuscle(context: CoachContext, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        guard dials.phase.isSurplus, !context.liftSets.isEmpty else { return nil }
        let weeks = LiftAnalytics.weeklyHardSets(sets: context.liftSets, map: context.muscleMap, weeks: dials.undertrainedWeeks, today: today, calendar: calendar)
        guard weeks.count == dials.undertrainedWeeks else { return nil }
        let unlocked = LiftAnalytics.unlockedMuscles(sets: context.liftSets, map: context.muscleMap, dials: dials, today: today, calendar: calendar)
        let target = Double(dials.hardSetsTargetPerWeek)
        let under = unlocked.filter { m in weeks.allSatisfy { ($0.sets[m] ?? 0) < target } }.sorted()
        guard let worst = under.min(by: { (LiftAnalytics.averageWeeklySets(weeks)[$0] ?? 0) < (LiftAnalytics.averageWeeklySets(weeks)[$1] ?? 0) }) else { return nil }
        let avg = LiftAnalytics.averageWeeklySets(weeks)
        let exercises = LiftAnalytics.exercises(for: worst, in: context.liftSets, map: context.muscleMap).prefix(3)
        let names = under.map(\.title)
        return CoachRecommendation(
            rule: .undertrainedMuscle,
            date: today,
            headline: "Add sets for \(worst.title.lowercased())",
            reason: "\(Format.list(names)) averaged under \(dials.hardSetsTargetPerWeek) hard sets a week for \(dials.undertrainedWeeks) weeks. \(exercises.isEmpty ? "" : "Add a set or two of \(Format.list(Array(exercises))).")",
            math: under.map { CoachMathRow($0.title, "\(Format.number(avg[$0] ?? 0, 1)) sets/wk", numberID: "sets:\($0.rawValue)") } + [CoachMathRow("Target", "\(dials.hardSetsTargetPerWeek) sets/wk")],
            ifAccepted: "Nothing changes in the app. Add the sets in your program and the Progress tab will show them.",
            chart: CoachChart(title: "Hard sets per week", caption: "\(worst.title), last \(dials.undertrainedWeeks) weeks.", unit: "sets", series: [
                CoachSeries(name: worst.title, style: .bars, points: weeks.map { CoachPoint(date: $0.weekEnd, value: $0.sets[worst] ?? 0) }),
            ])
        )
    }

    static func proteinShort(context: CoachContext, snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        let week = lastWeek(context.log, today: today, calendar: calendar).filter { $0.proteinG != nil }
        guard week.count >= 3 else { return nil }
        let target = snapshot.targets.weeklyAverage.proteinG
        let hits = week.filter { ($0.proteinG ?? 0) >= target * 0.95 }.count
        guard hits < dials.proteinHitDaysPerWeek else { return nil }
        let avg = week.compactMap(\.proteinG).mean ?? 0
        return CoachRecommendation(
            rule: .proteinShort,
            date: today,
            headline: "Protein came in short",
            reason: "You hit \(Format.int(target)) g on \(hits) of \(week.count) days. Your average was \(Format.int(avg)) g.",
            math: [
                CoachMathRow("Target", "\(Format.int(target)) g", numberID: "protein"),
                CoachMathRow("Average last week", "\(Format.int(avg)) g"),
                CoachMathRow("Days hit", "\(hits) of \(week.count)"),
            ],
            ifAccepted: "Nothing changes. Aim for \(Format.int(target)) g on \(dials.proteinHitDaysPerWeek) of 7 days.",
            chart: CoachChart(title: "Protein", caption: "Grams each day against the target.", unit: "g", series: [
                CoachSeries(name: "Eaten", style: .bars, points: week.sorted { $0.date < $1.date }.map { CoachPoint(date: $0.date, value: $0.proteinG ?? 0) }),
                CoachSeries(name: "Target", style: .dashed, points: week.sorted { $0.date < $1.date }.map { CoachPoint(date: $0.date, value: target) }),
            ])
        )
    }

    static func stepsDrifting(context: CoachContext, snapshot: EngineSnapshot, dials: Dials, today: Date, calendar: Calendar) -> CoachRecommendation? {
        let week = lastWeek(context.log, today: today, calendar: calendar).compactMap { $0.steps }.map(Double.init)
        guard week.count >= 4, let weekAvg = week.mean else { return nil }
        let windowAvg = snapshot.activity.stepsPerDay
        guard windowAvg > 0 else { return nil }
        let drop = (windowAvg - weekAvg) / windowAvg * 100
        guard drop > dials.stepsDropPercent else { return nil }
        let wKg = Units.kg(fromLb: snapshot.body.weightUsedLb)
        let impact = (windowAvg - weekAvg) * wKg * dials.stepCostKcalPerStepPerKg
        let covered: String
        switch dials.activitySource {
        case .modeled: covered = "Your target uses the \(dials.trustWindowDays)-day average, so it still assumes \(Format.int(windowAvg)) steps. It does not cover the drop yet."
        case .watch: covered = "Your target comes from Watch active energy, which already reflects fewer steps."
        case .blend: covered = "Part of your target comes from Watch active energy, so some of the drop is already covered."
        }
        let weeklySteps = stride(from: 1, through: 4, by: 1).compactMap { w -> CoachPoint? in
            let days = context.log.filter { let d = calendar.days(from: $0.date, to: today); return d >= (w - 1) * 7 + 1 && d <= w * 7 }.compactMap { $0.steps }.map(Double.init)
            guard let m = days.mean, let date = calendar.date(byAdding: .day, value: -((w - 1) * 7 + 1), to: today) else { return nil }
            return CoachPoint(date: date, value: m)
        }.reversed()
        return CoachRecommendation(
            rule: .stepsDrifting,
            date: today,
            headline: "Steps dropped \(Format.int(drop))%",
            reason: "Last week averaged \(Format.int(weekAvg)) steps against \(Format.int(windowAvg)) over your window. That's about \(Format.int(impact)) kcal/day less burned.",
            math: [
                CoachMathRow("Last week", "\(Format.int(weekAvg)) steps", numberID: "steps"),
                CoachMathRow("\(dials.trustWindowDays)-day average", "\(Format.int(windowAvg)) steps"),
                CoachMathRow("Impact", "−\(Format.int(impact)) kcal/day", highlighted: true),
            ],
            ifAccepted: covered,
            chart: CoachChart(title: "Weekly steps", caption: "Average steps per day, each of the last four weeks.", unit: "steps", series: [
                CoachSeries(name: "Steps", style: .bars, points: Array(weeklySteps)),
            ])
        )
    }
}

extension GoalRate {
    var percentPercentSafe: Double { percentPerWeek.isFinite ? percentPerWeek : 0 }
}

/// Small formatting helpers for coach text. Screens format their own numbers.
public enum Format {
    public static func int(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? String(Int(v.rounded()))
    }

    public static func number(_ v: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", v)
    }

    public static func signed(_ v: Double, _ digits: Int) -> String {
        let s = digits == 0 ? int(abs(v)) : number(abs(v), digits)
        if v > 0 { return "+" + s }
        if v < 0 { return "−" + s }
        return s
    }

    public static func weeks(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight"]
        let w = n < words.count ? words[n] : String(n)
        return "\(w) week\(n == 1 ? "" : "s")"
    }

    public static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    public static func weekdayName(_ weekday: Int, calendar: Calendar) -> String {
        let names = calendar.weekdaySymbols
        let i = max(1, min(7, weekday)) - 1
        return i < names.count ? names[i] : "Sunday"
    }
}
