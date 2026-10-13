import Foundation

public struct BodyProfile: Equatable, Sendable {
    public let weightUsedLb: Double
    public let weightSource: WeightSource
    public let trendWeightLb: Double?
    public let latestWeighInLb: Double?
    public let latestWeighInDate: Date?
    public let bodyFatPercent: Double?
    public let leanMassLb: Double?
    public let ageYears: Double?
    public let heightCm: Double?
    public let sex: Sex
}

public enum TrainingDaySource: String, Sendable {
    case workout, schedule, manual, override, none
}

/// The engine's full output for one day. Every number a screen shows comes from here.
public struct EngineSnapshot: Equatable, Sendable {
    public let date: Date
    public let body: BodyProfile
    public let bmr: BMRResult
    public let activity: ActivityProfile
    public let formula: FormulaTDEEResult
    public let observed: ObservedTDEEResult
    public let targets: TargetsResult
    public let trend: [TrendPoint]
    /// Least-squares slope of trend weight over the trust window, in lb per week.
    public let actualRateLbPerWeek: Double?
    public let actualRatePercentPerWeek: Double?
    public let isTrainingDay: Bool
    public let trainingDaySource: TrainingDaySource
    /// Today's calories and macros, with the weekday offset applied.
    public let today: DayTargets
    public let todayLog: DayInput?
    public let phaseWeek: Int?
    public let warnings: [String]

    public var eatenCalories: Double { todayLog?.calories ?? 0 }
    public var remainingCalories: Double { today.calories - eatenCalories }
    public var maintenance: Double { targets.maintenance }
}

public enum Engine {

    /// Computes everything for `today` from the log and the dials.
    public static func compute(log: [DayInput], dials: Dials, today: Date = Date(), calendar: Calendar = .current) -> EngineSnapshot {
        var warnings: [String] = []
        let todayStart = calendar.startOfDay(for: today)
        let sorted = log.filter { $0.date <= today }.sorted { $0.date < $1.date }
        let n = max(1, dials.trustWindowDays)

        // Body
        let trend = TrendWeight.series(log: sorted, dials: dials)
        let latest = sorted.last { $0.weightLb != nil }
        let trendWeight = trend.last?.trendLb
        var weightUsed: Double
        switch dials.weightSource {
        case .trend: weightUsed = trendWeight ?? latest?.weightLb ?? dials.manualWeightLb ?? 0
        case .latest: weightUsed = latest?.weightLb ?? trendWeight ?? dials.manualWeightLb ?? 0
        case .manual: weightUsed = dials.manualWeightLb ?? trendWeight ?? latest?.weightLb ?? 0
        }
        if weightUsed <= 0 {
            weightUsed = dials.goalWeightLb ?? 170
            warnings.append("No weigh-ins yet. Using \(Int(weightUsed)) lb until one arrives.")
        }

        var bodyFat: Double?
        var leanMass: Double?
        switch dials.bodyFatSource {
        case .manual:
            bodyFat = dials.bodyFatPercentManual
        case .health:
            let bfDay = sorted.last { $0.bodyFatPercent != nil }
            bodyFat = bfDay?.bodyFatPercent
            leanMass = sorted.last { $0.leanMassLb != nil }?.leanMassLb
        case .none:
            break
        }
        if leanMass == nil, let bf = bodyFat, bf > 0, bf < 100 {
            leanMass = weightUsed * (1 - bf / 100)
        }
        if bodyFat == nil, let lbm = leanMass, weightUsed > 0 {
            bodyFat = (1 - lbm / weightUsed) * 100
        }

        var age: Double?
        if let birth = dials.birthDate {
            let comps = calendar.dateComponents([.year, .month, .day], from: birth, to: todayStart)
            age = Double(comps.year ?? 0) + Double(comps.month ?? 0) / 12 + Double(comps.day ?? 0) / 365
        }

        let body = BodyProfile(weightUsedLb: weightUsed, weightSource: dials.weightSource, trendWeightLb: trendWeight, latestWeighInLb: latest?.weightLb, latestWeighInDate: latest?.date, bodyFatPercent: bodyFat, leanMassLb: leanMass, ageYears: age, heightCm: dials.heightCm, sex: dials.sex)

        // BMR
        let bmrInputs = BMRInputs(weightKg: Units.kg(fromLb: weightUsed), heightCm: dials.heightCm, ageYears: age, sex: dials.sex, leanMassKg: leanMass.map(Units.kg(fromLb:)))
        let bmr = BMRCalculator.compute(bmrInputs, dials: dials)
        if bmr.isFallback { warnings.append("Add height and date of birth in Dials for a real BMR.") }

        // Activity and observed
        let activity = ActivityProfile.from(log: sorted, today: today, dials: dials, calendar: calendar)
        let observed = ObservedTDEE.compute(log: sorted, today: today, dials: dials, calendar: calendar)

        var trust = 0.0
        if observed.isAvailable {
            trust = min(1, Double(observed.daysWithCalories) / Double(n)) * (dials.maxTrustPercent / 100)
        }

        let goalRate = GoalRate.compute(dials: dials, weightLb: weightUsed, today: today, calendar: calendar)
        let liftDays = activity.liftDaysPerWeek
        let trainingHours = activity.liftSessionMinutes / 60

        // TEF loop: targets depend on TEF, which depends on targets. Four passes settle it.
        var tef = 0.0
        var formula = FormulaTDEE.compute(bmr: bmr.value, weightLb: weightUsed, activity: activity, tef: tef, dials: dials)
        var maintenance = 0.0
        var base = 0.0
        var hitFloor = false
        var hitCeiling = false
        for _ in 0..<4 {
            formula = FormulaTDEE.compute(bmr: bmr.value, weightLb: weightUsed, activity: activity, tef: tef, dials: dials)
            let weekly = formula.weeklyAverage(liftDaysPerWeek: liftDays)
            maintenance = trust * (observed.value ?? 0) + (1 - trust) * weekly
            let clamped = clamp(maintenance + goalRate.dailyKcal, dials: dials)
            base = clamped.value
            hitFloor = clamped.hitFloor
            hitCeiling = clamped.hitCeiling
            let macros = Macros.targets(calories: base, dayType: .weeklyAverage, weightLb: weightUsed, leanMassLb: leanMass, trainingHours: trainingHours * liftDays / 7, dials: dials)
            tef = TEF.kcal(proteinG: macros.proteinG, carbsG: macros.carbsG, fatG: macros.fatG, dials: dials)
        }

        // Cycling
        var gap = 0.0
        if dials.cyclingEnabled {
            gap = (formula.trainingDay - formula.restDay) * dials.cyclingShiftPercent / 100
        }
        let restRaw = base - gap * min(7, max(0, liftDays)) / 7
        let trainRaw = restRaw + gap
        let restCal = Units.round(clamp(restRaw, dials: dials).value, toNearest: dials.roundingKcal)
        let trainCal = Units.round(clamp(trainRaw, dials: dials).value, toNearest: dials.roundingKcal)
        let baseRounded = Units.round(base, toNearest: dials.roundingKcal)

        let rest = Macros.targets(calories: restCal, dayType: .rest, weightLb: weightUsed, leanMassLb: leanMass, trainingHours: 0, dials: dials)
        let training = Macros.targets(calories: trainCal, dayType: .training, weightLb: weightUsed, leanMassLb: leanMass, trainingHours: trainingHours, dials: dials)
        let weekly = Macros.targets(calories: baseRounded, dayType: .weeklyAverage, weightLb: weightUsed, leanMassLb: leanMass, trainingHours: trainingHours * liftDays / 7, dials: dials)
        if rest.carbsBelowFloor || training.carbsBelowFloor {
            warnings.append("Carbs fall below your \(Int(dials.carbFloorGrams)) g floor. Lower protein or fat, or raise calories.")
        }

        let targets = TargetsResult(trust: trust, daysLogged: observed.daysWithCalories, windowDays: n, observedTDEE: observed.value, formulaRest: formula.restDay, formulaTraining: formula.trainingDay, formulaWeeklyAverage: formula.weeklyAverage(liftDaysPerWeek: liftDays), maintenance: maintenance, goalRate: goalRate, liftDaysPerWeek: liftDays, baseTarget: baseRounded, cyclingGap: gap, rest: rest, training: training, weeklyAverage: weekly, hitFloor: hitFloor, hitCeiling: hitCeiling, tef: tef)

        // Today
        let todayLog = sorted.last { calendar.isDate($0.date, inSameDayAs: today) }
        let (isTraining, source) = trainingDayStatus(todayLog: todayLog, today: today, dials: dials, calendar: calendar)
        let weekday = calendar.component(.weekday, from: today)
        let offset = dials.weekdayOffset(forWeekday: weekday)
        let todayRaw = (isTraining ? trainCal : restCal) + offset
        let todayCal = Units.round(clamp(todayRaw, dials: dials).value, toNearest: dials.roundingKcal)
        let todayTargets = Macros.targets(calories: todayCal, dayType: isTraining ? .training : .rest, weightLb: weightUsed, leanMassLb: leanMass, trainingHours: isTraining ? trainingHours : 0, dials: dials)

        // Actual rate: slope of the trend line over the window.
        let trendInWindow = trend.filter { calendar.days(from: $0.date, to: today) < n && !$0.isOutlier }
            .map { (x: Double(-calendar.days(from: $0.date, to: today)), y: $0.trendLb) }
        let rateFit = LinearFit.fit(trendInWindow)
        let actualRate = rateFit.map { $0.slope * 7 }

        var phaseWeek: Int?
        if let start = dials.phaseStartDate {
            phaseWeek = max(1, calendar.days(from: start, to: today) / 7 + 1)
        }

        return EngineSnapshot(date: todayStart, body: body, bmr: bmr, activity: activity, formula: formula, observed: observed, targets: targets, trend: trend, actualRateLbPerWeek: actualRate, actualRatePercentPerWeek: actualRate.map { $0 / weightUsed * 100 }, isTrainingDay: isTraining, trainingDaySource: source, today: todayTargets, todayLog: todayLog, phaseWeek: phaseWeek, warnings: warnings)
    }

    static func trainingDayStatus(todayLog: DayInput?, today: Date, dials: Dials, calendar: Calendar) -> (Bool, TrainingDaySource) {
        if let override = todayLog?.liftingOverride { return (override, .override) }
        switch dials.trainingDayDetection {
        case .workout:
            if todayLog?.hasLift == true { return (true, .workout) }
            return (false, .none)
        case .schedule:
            let weekday = calendar.component(.weekday, from: today)
            return (dials.scheduledTrainingWeekdays.contains(weekday), .schedule)
        case .manual:
            return (false, .manual)
        }
    }

    private static func clamp(_ value: Double, dials: Dials) -> (value: Double, hitFloor: Bool, hitCeiling: Bool) {
        var v = value
        var floor = false
        var ceiling = false
        if let f = dials.calorieFloor, v < f { v = f; floor = true }
        if let c = dials.calorieCeiling, v > c { v = c; ceiling = true }
        return (v, floor, ceiling)
    }

    // MARK: Sensitivity

    /// How much today's calorie target moves when one dial takes a new value.
    public static func targetChange(log: [DayInput], dials: Dials, key: DialKey, newValue: DialValue, today: Date = Date(), calendar: Calendar = .current) -> Double {
        let current = compute(log: log, dials: dials, today: today, calendar: calendar).today.calories
        let changed = compute(log: log, dials: dials.with(key, newValue), today: today, calendar: calendar).today.calories
        return changed - current
    }

    /// How much today's target differs from what it would be with this dial at its default.
    /// This is the "+38 kcal" badge on the Dials screen.
    public static func sensitivityFromDefault(log: [DayInput], dials: Dials, key: DialKey, today: Date = Date(), calendar: Calendar = .current) -> Double {
        guard let spec = DialCatalog.spec(for: key, in: dials) else { return 0 }
        let current = compute(log: log, dials: dials, today: today, calendar: calendar).today.calories
        let reset = compute(log: log, dials: dials.with(key, spec.defaultValue), today: today, calendar: calendar).today.calories
        return current - reset
    }

    /// Today's target as a function of one numeric dial across its range, for the sensitivity chart.
    public static func sensitivityCurve(log: [DayInput], dials: Dials, key: DialKey, samples: Int = 12, today: Date = Date(), calendar: Calendar = .current) -> [(value: Double, target: Double)] {
        guard let spec = DialCatalog.spec(for: key, in: dials), case .slider(let lo, let hi, _) = spec.kind, samples > 1 else { return [] }
        return (0..<samples).map { i in
            let v = lo + (hi - lo) * Double(i) / Double(samples - 1)
            let t = compute(log: log, dials: dials.with(key, .number(v)), today: today, calendar: calendar).today.calories
            return (v, t)
        }
    }

    // MARK: History

    public struct HistoryPoint: Equatable, Identifiable, Sendable {
        public var id: Date { date }
        public let date: Date
        public let observedTDEE: Double?
        public let formulaTDEE: Double
        public let maintenance: Double
        public let trust: Double
        public let target: Double
        public let eaten: Double?
        public let actualRateLbPerWeek: Double?
        public let goalRateLbPerWeek: Double
    }

    /// Recomputes the snapshot for each of the last `days` days so charts can show how
    /// the estimates moved. Dials are held at their current values.
    public static func history(log: [DayInput], dials: Dials, days: Int, today: Date = Date(), calendar: Calendar = .current) -> [HistoryPoint] {
        guard days > 0 else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        return (0..<days).reversed().compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: todayStart) else { return nil }
            let s = compute(log: log, dials: dials, today: date, calendar: calendar)
            return HistoryPoint(date: date, observedTDEE: s.observed.value, formulaTDEE: s.targets.formulaWeeklyAverage, maintenance: s.targets.maintenance, trust: s.targets.trust, target: s.today.calories, eaten: s.todayLog?.calories, actualRateLbPerWeek: s.actualRateLbPerWeek, goalRateLbPerWeek: s.targets.goalRate.lbPerWeek)
        }
    }

    /// Where the plan says weight should be on each day from the phase start, at the goal rate.
    public static func goalPath(from startDate: Date, startWeightLb: Double, lbPerWeek: Double, through endDate: Date, calendar: Calendar = .current) -> [(date: Date, weightLb: Double)] {
        let days = calendar.days(from: startDate, to: endDate)
        guard days >= 0 else { return [] }
        let start = calendar.startOfDay(for: startDate)
        return (0...days).compactMap { d in
            guard let date = calendar.date(byAdding: .day, value: d, to: start) else { return nil }
            return (date, startWeightLb + lbPerWeek / 7 * Double(d))
        }
    }
}
