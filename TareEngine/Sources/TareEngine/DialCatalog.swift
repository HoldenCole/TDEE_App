import Foundation

// MARK: - Keys

/// Stable identifier for one editable value in `Dials`. Dynamic entries (one MET per
/// lifting style or cardio type) use a prefix plus the entry name.
public struct DialKey: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    // Profile
    public static let sex = DialKey("profile.sex")
    public static let birthDate = DialKey("profile.birthDate")
    public static let heightCm = DialKey("profile.heightCm")
    public static let phase = DialKey("profile.phase")
    public static let phaseStartDate = DialKey("profile.phaseStartDate")

    // Body
    public static let weightSource = DialKey("body.weightSource")
    public static let manualWeightLb = DialKey("body.manualWeightLb")
    public static let trendAlpha = DialKey("body.trendAlpha")
    public static let outlierThresholdLb = DialKey("body.outlierThresholdLb")
    public static let bodyFatSource = DialKey("body.bodyFatSource")
    public static let bodyFatPercentManual = DialKey("body.bodyFatPercentManual")

    // BMR
    public static let bmrFormula = DialKey("bmr.formula")
    public static let bmrWeightMifflin = DialKey("bmr.weight.mifflin")
    public static let bmrWeightKatch = DialKey("bmr.weight.katchMcArdle")
    public static let bmrWeightCunningham = DialKey("bmr.weight.cunningham")
    public static let bmrWeightHarris = DialKey("bmr.weight.harrisBenedict")
    public static let measuredRMR = DialKey("bmr.measuredRMR")
    public static let bmrAdjustmentPercent = DialKey("bmr.adjustmentPercent")

    // Activity
    public static let activitySource = DialKey("activity.source")
    public static let activityBlendWatchShare = DialKey("activity.blendWatchShare")
    public static let watchCorrection = DialKey("activity.watchCorrection")
    public static let dailyLivingPercent = DialKey("activity.dailyLivingPercent")
    public static let stepCost = DialKey("activity.stepCost")
    public static let defaultLiftStyle = DialKey("activity.defaultLiftStyle")
    public static let liftMETPrefix = "activity.liftMET."
    public static func liftMET(_ style: String) -> DialKey { DialKey(liftMETPrefix + style) }
    public static let liftDurationSource = DialKey("activity.liftDurationSource")
    public static let fixedLiftMinutes = DialKey("activity.fixedLiftMinutes")
    public static let postWorkoutBurnPercent = DialKey("activity.postWorkoutBurnPercent")
    public static let cardioMETPrefix = "activity.cardioMET."
    public static func cardioMET(_ type: String) -> DialKey { DialKey(cardioMETPrefix + type) }

    // Digestion
    public static let tefMode = DialKey("digestion.tefMode")
    public static let tefProteinPercent = DialKey("digestion.tefProteinPercent")
    public static let tefCarbPercent = DialKey("digestion.tefCarbPercent")
    public static let tefFatPercent = DialKey("digestion.tefFatPercent")
    public static let tefFlatPercent = DialKey("digestion.tefFlatPercent")

    // Adaptive
    public static let trustWindowDays = DialKey("adaptive.trustWindowDays")
    public static let minDaysBeforeTrust = DialKey("adaptive.minDaysBeforeTrust")
    public static let maxTrustPercent = DialKey("adaptive.maxTrustPercent")
    public static let kcalPerLb = DialKey("adaptive.kcalPerLb")
    public static let incompleteFoodDays = DialKey("adaptive.incompleteFoodDays")
    public static let metabolicAdaptationPercent = DialKey("adaptive.metabolicAdaptationPercent")

    // Goal
    public static let rateMode = DialKey("goal.rateMode")
    public static let ratePercentPerWeek = DialKey("goal.ratePercentPerWeek")
    public static let rateLbPerWeek = DialKey("goal.rateLbPerWeek")
    public static let fixedKcalOffset = DialKey("goal.fixedKcalOffset")
    public static let goalWeightLb = DialKey("goal.goalWeightLb")
    public static let goalDate = DialKey("goal.goalDate")
    public static let calorieFloor = DialKey("goal.calorieFloor")
    public static let calorieCeiling = DialKey("goal.calorieCeiling")

    // Cycling
    public static let cyclingEnabled = DialKey("cycling.enabled")
    public static let cyclingShiftPercent = DialKey("cycling.shiftPercent")
    public static let trainingDayDetection = DialKey("cycling.trainingDayDetection")
    public static let scheduledTrainingWeekdays = DialKey("cycling.scheduledTrainingWeekdays")
    public static let weekdayOffsets = DialKey("cycling.weekdayOffsets")

    // Macros
    public static let proteinGramsPerLb = DialKey("macros.proteinGramsPerLb")
    public static let proteinBasis = DialKey("macros.proteinBasis")
    public static let fatMode = DialKey("macros.fatMode")
    public static let fatGramsPerLb = DialKey("macros.fatGramsPerLb")
    public static let fatPercentOfCalories = DialKey("macros.fatPercentOfCalories")
    public static let carbFloorGrams = DialKey("macros.carbFloorGrams")
    public static let fiberGramsPer1000Kcal = DialKey("macros.fiberGramsPer1000Kcal")
    public static let dayTypeOverridesEnabled = DialKey("macros.dayTypeOverridesEnabled")
    public static let trainingProteinGramsPerLb = DialKey("macros.trainingProteinGramsPerLb")
    public static let trainingFatGramsPerLb = DialKey("macros.trainingFatGramsPerLb")
    public static let restProteinGramsPerLb = DialKey("macros.restProteinGramsPerLb")
    public static let restFatGramsPerLb = DialKey("macros.restFatGramsPerLb")

    // Coach
    public static let coachCheckInWeekday = DialKey("coach.checkInWeekday")
    public static let coachAutoApply = DialKey("coach.autoApply")
    public static let rateMissTolerancePercent = DialKey("coach.rateMissTolerancePercent")
    public static let rateMissCheckIns = DialKey("coach.rateMissCheckIns")
    public static let coachMaxChangeKcal = DialKey("coach.maxChangeKcal")
    public static let minLoggedDaysPerWeek = DialKey("coach.minLoggedDaysPerWeek")
    public static let strengthDropPercent = DialKey("coach.strengthDropPercent")
    public static let strengthDropLifts = DialKey("coach.strengthDropLifts")
    public static let strengthDropWeeks = DialKey("coach.strengthDropWeeks")
    public static let strengthSlowRatePercent = DialKey("coach.strengthSlowRatePercent")
    public static let longCutWeeks = DialKey("coach.longCutWeeks")
    public static let hardSetsTargetPerWeek = DialKey("coach.hardSetsTargetPerWeek")
    public static let undertrainedWeeks = DialKey("coach.undertrainedWeeks")
    public static let proteinHitDaysPerWeek = DialKey("coach.proteinHitDaysPerWeek")
    public static let stepsDropPercent = DialKey("coach.stepsDropPercent")
    public static let bodyFatCeilingPercent = DialKey("coach.bodyFatCeilingPercent")

    // Progress
    public static let muscleUnlockWeeks = DialKey("progress.muscleUnlockWeeks")
    public static let exerciseUnlockSessions = DialKey("progress.exerciseUnlockSessions")

    // Display
    public static let roundingKcal = DialKey("display.roundingKcal")
    public static let waterOzPerLb = DialKey("display.waterOzPerLb")
    public static let waterOzPerTrainingHour = DialKey("display.waterOzPerTrainingHour")
}

// MARK: - Values

/// A dial's value in a form the UI and the change log can handle without knowing the type.
public enum DialValue: Codable, Equatable, Sendable {
    case number(Double)
    case optionalNumber(Double?)
    case choice(String)
    case bool(Bool)
    case date(Date?)
    case intList([Int])
    case numberList([Double])

    public var doubleValue: Double? {
        switch self {
        case .number(let v): return v
        case .optionalNumber(let v): return v
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    public var choiceValue: String? {
        if case .choice(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Short text for the change log, e.g. "5.5" or "Hevy". Formatting for display belongs to the UI.
    public var compactDescription: String {
        switch self {
        case .number(let v): return DialValue.format(v)
        case .optionalNumber(let v): return v.map(DialValue.format) ?? "Off"
        case .choice(let s): return s
        case .bool(let b): return b ? "On" : "Off"
        case .date(let d):
            guard let d else { return "Off" }
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: d)
        case .intList(let l): return l.map(String.init).joined(separator: ",")
        case .numberList(let l): return l.map(DialValue.format).joined(separator: ",")
        }
    }

    static func format(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1_000_000 { return String(Int(v)) }
        var s = String(format: "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

// MARK: - Specs

public enum DialGroup: String, CaseIterable, Codable, Sendable {
    case profile, body, bmr, activity, digestion, adaptive, goal, cycling, macros, coach, progress, display

    public var title: String {
        switch self {
        case .profile: return "Profile"
        case .body: return "Body"
        case .bmr: return "BMR"
        case .activity: return "Activity"
        case .digestion: return "Digestion"
        case .adaptive: return "Adaptive"
        case .goal: return "Goal"
        case .cycling: return "Cycling"
        case .macros: return "Macros"
        case .coach: return "Coach"
        case .progress: return "Progress"
        case .display: return "Display"
        }
    }

    /// The groups that make up the 35 core dials from the spec table.
    public static let coreGroups: [DialGroup] = [.body, .bmr, .activity, .digestion, .adaptive, .goal, .cycling, .macros, .display]
}

public struct DialChoice: Equatable, Sendable {
    public let id: String
    public let title: String
    public init(_ id: String, _ title: String) {
        self.id = id
        self.title = title
    }
}

public enum DialKind: Equatable, Sendable {
    /// A continuous value. `step` is the slider increment.
    case slider(min: Double, max: Double, step: Double)
    /// A number typed in. `nil` means off; `allowsOff` controls whether that's offered.
    case number(min: Double?, max: Double?, allowsOff: Bool)
    case choice([DialChoice])
    case toggle
    case date(allowsNone: Bool)
    /// Set of weekdays 1…7.
    case weekdaySet
    /// Seven kcal offsets, Sunday first.
    case weekdayOffsets
}

/// Metadata for one editable value. `row` groups several keys under one spec-table row
/// (e.g. the TEF rates), which is how the Dials screen counts "35 dials".
public struct DialSpec: Identifiable, Sendable {
    public var id: DialKey { key }
    public let key: DialKey
    public let group: DialGroup
    public let row: String
    public let title: String
    public let unit: String
    public let note: String
    public let kind: DialKind
    public let defaultValue: DialValue
    /// Whether changing this dial can move today's calorie target. Drives the sensitivity badge.
    public let affectsTarget: Bool

    public init(key: DialKey, group: DialGroup, row: String? = nil, title: String, unit: String = "", note: String, kind: DialKind, defaultValue: DialValue, affectsTarget: Bool = true) {
        self.key = key
        self.group = group
        self.row = row ?? key.rawValue
        self.title = title
        self.unit = unit
        self.note = note
        self.kind = kind
        self.defaultValue = defaultValue
        self.affectsTarget = affectsTarget
    }
}

// MARK: - Catalog

public enum DialCatalog {

    /// Every spec for the given dials, in display order. Dynamic entries follow the
    /// styles and cardio types currently defined.
    public static func specs(for dials: Dials) -> [DialSpec] {
        var out: [DialSpec] = []
        let d = Dials()

        // Profile
        out += [
            DialSpec(key: .sex, group: .profile, title: "Sex", note: "Used by the BMR formulas.", kind: .choice(Sex.allCases.map { DialChoice($0.rawValue, $0.rawValue.capitalized) }), defaultValue: .choice(d.sex.rawValue)),
            DialSpec(key: .birthDate, group: .profile, title: "Date of birth", note: "Age feeds Mifflin and Harris-Benedict.", kind: .date(allowsNone: true), defaultValue: .date(nil)),
            DialSpec(key: .heightCm, group: .profile, title: "Height", unit: "cm", note: "Feeds Mifflin and Harris-Benedict.", kind: .number(min: 100, max: 250, allowsOff: true), defaultValue: .optionalNumber(nil)),
            DialSpec(key: .phase, group: .profile, title: "Phase", note: "Cut, recomp, maintain, lean bulk or bulk. Sets the rate's usual range and which coach rules apply.", kind: .choice(Phase.allCases.map { DialChoice($0.rawValue, $0.title) }), defaultValue: .choice(d.phase.rawValue), affectsTarget: false),
            DialSpec(key: .phaseStartDate, group: .profile, title: "Phase started", note: "The goal path on the Coach chart starts here.", kind: .date(allowsNone: true), defaultValue: .date(nil), affectsTarget: false),
        ]

        // Body
        out += [
            DialSpec(key: .weightSource, group: .body, row: "body.weight", title: "Weight used", note: "Which weight the formulas and macros use. Trend ignores water and sodium swings.", kind: .choice([DialChoice("trend", "Trend weight"), DialChoice("latest", "Latest weigh-in"), DialChoice("manual", "Manual")]), defaultValue: .choice(d.weightSource.rawValue)),
            DialSpec(key: .manualWeightLb, group: .body, row: "body.weight", title: "Manual weight", unit: "lb", note: "Used when Weight used is Manual.", kind: .number(min: 50, max: 500, allowsOff: true), defaultValue: .optionalNumber(nil)),
            DialSpec(key: .trendAlpha, group: .body, title: "Trend smoothing", unit: "α", note: "Lower is smoother and slower. 0.10 means each weigh-in moves the trend 10% of the way.", kind: .slider(min: 0.05, max: 0.25, step: 0.01), defaultValue: .number(d.trendAlpha)),
            DialSpec(key: .outlierThresholdLb, group: .body, title: "Outlier filter", unit: "lb", note: "Weigh-ins this far off the trend are ignored. Three in a row are accepted.", kind: .number(min: 1, max: 6, allowsOff: true), defaultValue: .optionalNumber(d.outlierThresholdLb)),
            DialSpec(key: .bodyFatSource, group: .body, row: "body.bodyFat", title: "Body fat source", note: "Lean mass feeds Katch-McArdle and Cunningham.", kind: .choice([DialChoice("manual", "Manual"), DialChoice("health", "Apple Health"), DialChoice("none", "None")]), defaultValue: .choice(d.bodyFatSource.rawValue)),
            DialSpec(key: .bodyFatPercentManual, group: .body, row: "body.bodyFat", title: "Body fat", unit: "%", note: "Your estimate, used when the source is Manual.", kind: .number(min: 3, max: 60, allowsOff: true), defaultValue: .optionalNumber(nil)),
        ]

        // BMR
        out += [
            DialSpec(key: .bmrFormula, group: .bmr, row: "bmr.formula", title: "Formula", note: "Average uses every formula your data allows. Katch and Cunningham need body fat.", kind: .choice([
                DialChoice("average", "Average of available"), DialChoice("mifflin", "Mifflin-St Jeor"), DialChoice("katchMcArdle", "Katch-McArdle"), DialChoice("cunningham", "Cunningham"), DialChoice("harrisBenedict", "Harris-Benedict"), DialChoice("weighted", "Weighted blend"),
            ]), defaultValue: .choice(d.bmrFormula.rawValue)),
            DialSpec(key: .bmrWeightMifflin, group: .bmr, row: "bmr.formula", title: "Mifflin weight", note: "Weight in the blend.", kind: .slider(min: 0, max: 1, step: 0.05), defaultValue: .number(d.bmrWeights.mifflin)),
            DialSpec(key: .bmrWeightKatch, group: .bmr, row: "bmr.formula", title: "Katch-McArdle weight", note: "Weight in the blend.", kind: .slider(min: 0, max: 1, step: 0.05), defaultValue: .number(d.bmrWeights.katchMcArdle)),
            DialSpec(key: .bmrWeightCunningham, group: .bmr, row: "bmr.formula", title: "Cunningham weight", note: "Weight in the blend.", kind: .slider(min: 0, max: 1, step: 0.05), defaultValue: .number(d.bmrWeights.cunningham)),
            DialSpec(key: .bmrWeightHarris, group: .bmr, row: "bmr.formula", title: "Harris-Benedict weight", note: "Weight in the blend.", kind: .slider(min: 0, max: 1, step: 0.05), defaultValue: .number(d.bmrWeights.harrisBenedict)),
            DialSpec(key: .measuredRMR, group: .bmr, title: "Measured RMR override", unit: "kcal", note: "From a lab test. Replaces every formula while set.", kind: .number(min: 800, max: 4000, allowsOff: true), defaultValue: .optionalNumber(nil)),
            DialSpec(key: .bmrAdjustmentPercent, group: .bmr, title: "BMR adjustment", unit: "%", note: "Nudge the formula result if you know you run hot or cold.", kind: .slider(min: -15, max: 15, step: 1), defaultValue: .number(d.bmrAdjustmentPercent)),
        ]

        // Activity
        out += [
            DialSpec(key: .activitySource, group: .activity, row: "activity.source", title: "Activity source", note: "Modeled from steps and workouts, or Apple Watch active energy, or a blend.", kind: .choice([DialChoice("modeled", "Modeled"), DialChoice("watch", "Apple Watch"), DialChoice("blend", "Blend")]), defaultValue: .choice(d.activitySource.rawValue)),
            DialSpec(key: .activityBlendWatchShare, group: .activity, row: "activity.source", title: "Watch share of blend", note: "0 is all modeled, 1 is all Watch.", kind: .slider(min: 0, max: 1, step: 0.05), defaultValue: .number(d.activityBlendWatchShare)),
            DialSpec(key: .watchCorrection, group: .activity, title: "Watch correction", unit: "×", note: "Apple Watch overstates active energy for most people. 0.85 keeps 85% of it.", kind: .slider(min: 0.5, max: 1.0, step: 0.01), defaultValue: .number(d.watchCorrection)),
            DialSpec(key: .dailyLivingPercent, group: .activity, title: "Daily living", unit: "% of BMR", note: "Fidgeting, standing and chores your watch doesn't count as steps. Desk job 8–10%, on your feet 15%.", kind: .slider(min: 0, max: 25, step: 1), defaultValue: .number(d.dailyLivingPercent)),
            DialSpec(key: .stepCost, group: .activity, title: "Step cost", unit: "kcal / step / kg", note: "About 42 kcal per 1,000 steps at 84 kg. Raise it if you walk hills or carry weight.", kind: .slider(min: 0.0003, max: 0.0007, step: 0.00001), defaultValue: .number(d.stepCostKcalPerStepPerKg)),
        ]
        out.append(DialSpec(key: .defaultLiftStyle, group: .activity, row: "activity.liftMET", title: "Lifting style", note: "Used when a workout doesn't say. Heavy with long rests 3.5, hypertrophy 5.0, supersets 6.0.", kind: .choice(dials.liftStyles.map { DialChoice($0.name, $0.name) }), defaultValue: .choice(d.defaultLiftStyle)))
        for style in dials.liftStyles {
            let def = Dials.defaultLiftStyles.first(where: { $0.name == style.name })?.met ?? style.met
            out.append(DialSpec(key: .liftMET(style.name), group: .activity, row: "activity.liftMET", title: "\(style.name) intensity", unit: "MET", note: "Energy cost of a \(style.name.lowercased()) session, above resting.", kind: .slider(min: 2.5, max: 8.0, step: 0.1), defaultValue: .number(def)))
        }
        out += [
            DialSpec(key: .liftDurationSource, group: .activity, row: "activity.liftDuration", title: "Lift duration", note: "From your workouts in Health, or a fixed length per session.", kind: .choice([DialChoice("workouts", "From workouts"), DialChoice("fixed", "Fixed minutes")]), defaultValue: .choice(d.liftDurationSource.rawValue)),
            DialSpec(key: .fixedLiftMinutes, group: .activity, row: "activity.liftDuration", title: "Fixed session length", unit: "min", note: "Used when Lift duration is Fixed.", kind: .slider(min: 15, max: 180, step: 5), defaultValue: .number(d.fixedLiftMinutes)),
            DialSpec(key: .postWorkoutBurnPercent, group: .activity, title: "Post-workout burn", unit: "%", note: "Extra % of each session, after it ends.", kind: .slider(min: 0, max: 15, step: 1), defaultValue: .number(d.postWorkoutBurnPercent)),
        ]
        for type in dials.cardioTypes {
            let def = Dials.defaultCardioTypes.first(where: { $0.name == type.name })?.met ?? type.met
            out.append(DialSpec(key: .cardioMET(type.name), group: .activity, row: "activity.cardioMET", title: "\(type.name) intensity", unit: "MET", note: "Energy cost of \(type.name.lowercased()), above resting.", kind: .slider(min: 2.0, max: 16.0, step: 0.1), defaultValue: .number(def)))
        }

        // Digestion
        out += [
            DialSpec(key: .tefMode, group: .digestion, row: "digestion.tef", title: "Digestion", note: "By macro counts the thermic effect of each macro separately; flat uses one rate for everything.", kind: .choice([DialChoice("byMacro", "By macro"), DialChoice("flat", "Flat rate")]), defaultValue: .choice(d.tefMode.rawValue)),
            DialSpec(key: .tefProteinPercent, group: .digestion, row: "digestion.tef", title: "Protein TEF", unit: "%", note: "Share of protein calories burned digesting them.", kind: .slider(min: 0, max: 35, step: 0.5), defaultValue: .number(d.tefProteinPercent)),
            DialSpec(key: .tefCarbPercent, group: .digestion, row: "digestion.tef", title: "Carb TEF", unit: "%", note: "Share of carb calories burned digesting them.", kind: .slider(min: 0, max: 35, step: 0.5), defaultValue: .number(d.tefCarbPercent)),
            DialSpec(key: .tefFatPercent, group: .digestion, row: "digestion.tef", title: "Fat TEF", unit: "%", note: "Share of fat calories burned digesting them.", kind: .slider(min: 0, max: 35, step: 0.5), defaultValue: .number(d.tefFatPercent)),
            DialSpec(key: .tefFlatPercent, group: .digestion, row: "digestion.tef", title: "Flat TEF", unit: "%", note: "Used when Digestion is Flat rate.", kind: .slider(min: 0, max: 35, step: 0.5), defaultValue: .number(d.tefFlatPercent)),
        ]

        // Adaptive
        out += [
            DialSpec(key: .trustWindowDays, group: .adaptive, title: "Trust window", unit: "days", note: "How far back the observed TDEE looks. Longer is steadier, shorter reacts faster.", kind: .slider(min: 7, max: 56, step: 1), defaultValue: .number(Double(d.trustWindowDays))),
            DialSpec(key: .minDaysBeforeTrust, group: .adaptive, title: "Days before trusting data", unit: "days", note: "Observed TDEE needs at least this many days with calories and with weigh-ins.", kind: .slider(min: 5, max: 14, step: 1), defaultValue: .number(Double(d.minDaysBeforeTrust))),
            DialSpec(key: .maxTrustPercent, group: .adaptive, title: "Max trust", unit: "%", note: "The most weight the observed TDEE can get in the blend, even with a full window.", kind: .slider(min: 0, max: 100, step: 5), defaultValue: .number(d.maxTrustPercent)),
            DialSpec(key: .kcalPerLb, group: .adaptive, title: "Energy per lb of change", unit: "kcal", note: "3,500 for fat. A lean bulk adds some muscle, which stores less energy per pound.", kind: .slider(min: 2000, max: 3500, step: 50), defaultValue: .number(d.kcalPerLb)),
            DialSpec(key: .incompleteFoodDays, group: .adaptive, title: "Incomplete food days", note: "Days you marked as incompletely logged.", kind: .choice([DialChoice("exclude", "Exclude"), DialChoice("include", "Include")]), defaultValue: .choice(d.incompleteFoodDays.rawValue)),
            DialSpec(key: .metabolicAdaptationPercent, group: .adaptive, title: "Metabolic adaptation", unit: "%", note: "Reduces the formula TDEE for adaptation during a long cut.", kind: .slider(min: 0, max: 15, step: 0.5), defaultValue: .number(d.metabolicAdaptationPercent)),
        ]

        // Goal
        out += [
            DialSpec(key: .rateMode, group: .goal, row: "goal.rateMode", title: "Rate mode", note: "How the goal is expressed.", kind: .choice([DialChoice("percentPerWeek", "% bodyweight / wk"), DialChoice("lbPerWeek", "lb / wk"), DialChoice("fixedKcal", "Fixed kcal"), DialChoice("goalWeightByDate", "Goal weight by date")]), defaultValue: .choice(d.rateMode.rawValue)),
            DialSpec(key: .ratePercentPerWeek, group: .goal, row: "goal.rate", title: "Rate", unit: "% / wk", note: "Negative loses, positive gains.", kind: .slider(min: -1.5, max: 1.0, step: 0.05), defaultValue: .number(d.ratePercentPerWeek)),
            DialSpec(key: .rateLbPerWeek, group: .goal, row: "goal.rate", title: "Rate", unit: "lb / wk", note: "Used in lb / wk mode.", kind: .slider(min: -3, max: 2, step: 0.1), defaultValue: .number(d.rateLbPerWeek)),
            DialSpec(key: .fixedKcalOffset, group: .goal, row: "goal.rate", title: "Daily surplus or deficit", unit: "kcal", note: "Used in Fixed kcal mode.", kind: .slider(min: -1000, max: 1000, step: 10), defaultValue: .number(d.fixedKcalOffset)),
            DialSpec(key: .goalWeightLb, group: .goal, row: "goal.rate", title: "Goal weight", unit: "lb", note: "Used in Goal weight by date mode.", kind: .number(min: 50, max: 500, allowsOff: true), defaultValue: .optionalNumber(nil)),
            DialSpec(key: .goalDate, group: .goal, row: "goal.rate", title: "Goal date", note: "Used in Goal weight by date mode.", kind: .date(allowsNone: true), defaultValue: .date(nil)),
            DialSpec(key: .calorieFloor, group: .goal, row: "goal.floorCeiling", title: "Calorie floor", unit: "kcal", note: "The target never goes below this.", kind: .number(min: 800, max: 6000, allowsOff: true), defaultValue: .optionalNumber(nil)),
            DialSpec(key: .calorieCeiling, group: .goal, row: "goal.floorCeiling", title: "Calorie ceiling", unit: "kcal", note: "The target never goes above this.", kind: .number(min: 800, max: 8000, allowsOff: true), defaultValue: .optionalNumber(nil)),
        ]

        // Cycling
        out += [
            DialSpec(key: .cyclingEnabled, group: .cycling, row: "cycling.cycling", title: "Calorie cycling", note: "More on lifting days, less on rest days. The weekly total stays the same.", kind: .toggle, defaultValue: .bool(d.cyclingEnabled)),
            DialSpec(key: .cyclingShiftPercent, group: .cycling, row: "cycling.cycling", title: "Shift", unit: "%", note: "100% moves the full training-day burn onto training days. 200% doubles it.", kind: .slider(min: 0, max: 200, step: 5), defaultValue: .number(d.cyclingShiftPercent)),
            DialSpec(key: .trainingDayDetection, group: .cycling, row: "cycling.detection", title: "Training day detection", note: "A strength workout in Health, a weekly schedule, or the toggle on Today.", kind: .choice([DialChoice("workout", "Workout in Health"), DialChoice("schedule", "Weekly schedule"), DialChoice("manual", "Manual")]), defaultValue: .choice(d.trainingDayDetection.rawValue)),
            DialSpec(key: .scheduledTrainingWeekdays, group: .cycling, row: "cycling.detection", title: "Training days", note: "Used in Weekly schedule mode.", kind: .weekdaySet, defaultValue: .intList(d.scheduledTrainingWeekdays)),
            DialSpec(key: .weekdayOffsets, group: .cycling, title: "Weekday offsets", unit: "kcal", note: "Add or subtract calories on a weekday, e.g. a Saturday refeed.", kind: .weekdayOffsets, defaultValue: .numberList(d.weekdayOffsets)),
        ]

        // Macros
        out += [
            DialSpec(key: .proteinGramsPerLb, group: .macros, row: "macros.protein", title: "Protein", unit: "g / lb", note: "0.8–1.0 g/lb covers almost everyone. Higher during a cut.", kind: .slider(min: 0.6, max: 1.5, step: 0.05), defaultValue: .number(d.proteinGramsPerLb)),
            DialSpec(key: .proteinBasis, group: .macros, row: "macros.protein", title: "Protein basis", note: "Multiply by bodyweight, lean mass or goal weight.", kind: .choice([DialChoice("bodyweight", "Bodyweight"), DialChoice("leanMass", "Lean mass"), DialChoice("goalWeight", "Goal weight")]), defaultValue: .choice(d.proteinBasis.rawValue)),
            DialSpec(key: .fatMode, group: .macros, row: "macros.fat", title: "Fat mode", note: "A floor in g per lb, or a share of calories.", kind: .choice([DialChoice("gramsPerLb", "g / lb floor"), DialChoice("percentOfCalories", "% of calories")]), defaultValue: .choice(d.fatMode.rawValue)),
            DialSpec(key: .fatGramsPerLb, group: .macros, row: "macros.fat", title: "Fat floor", unit: "g / lb", note: "0.3–0.4 g/lb keeps hormones happy.", kind: .slider(min: 0.2, max: 0.6, step: 0.05), defaultValue: .number(d.fatGramsPerLb)),
            DialSpec(key: .fatPercentOfCalories, group: .macros, row: "macros.fat", title: "Fat share", unit: "% kcal", note: "Used in % of calories mode.", kind: .slider(min: 15, max: 45, step: 1), defaultValue: .number(d.fatPercentOfCalories)),
            DialSpec(key: .carbFloorGrams, group: .macros, title: "Carb floor warning", unit: "g", note: "Warn when carbs would fall below this.", kind: .slider(min: 0, max: 200, step: 10), defaultValue: .number(d.carbFloorGrams), affectsTarget: false),
            DialSpec(key: .fiberGramsPer1000Kcal, group: .macros, title: "Fiber", unit: "g / 1,000 kcal", note: "14 g per 1,000 kcal is the usual guideline.", kind: .slider(min: 0, max: 25, step: 1), defaultValue: .number(d.fiberGramsPer1000Kcal), affectsTarget: false),
            DialSpec(key: .dayTypeOverridesEnabled, group: .macros, row: "macros.dayType", title: "Day-type overrides", note: "Separate protein and fat for training and rest days.", kind: .toggle, defaultValue: .bool(d.dayTypeOverridesEnabled)),
            DialSpec(key: .trainingProteinGramsPerLb, group: .macros, row: "macros.dayType", title: "Training protein", unit: "g / lb", note: "", kind: .slider(min: 0.6, max: 1.5, step: 0.05), defaultValue: .number(d.trainingProteinGramsPerLb)),
            DialSpec(key: .trainingFatGramsPerLb, group: .macros, row: "macros.dayType", title: "Training fat", unit: "g / lb", note: "", kind: .slider(min: 0.2, max: 0.6, step: 0.05), defaultValue: .number(d.trainingFatGramsPerLb)),
            DialSpec(key: .restProteinGramsPerLb, group: .macros, row: "macros.dayType", title: "Rest protein", unit: "g / lb", note: "", kind: .slider(min: 0.6, max: 1.5, step: 0.05), defaultValue: .number(d.restProteinGramsPerLb)),
            DialSpec(key: .restFatGramsPerLb, group: .macros, row: "macros.dayType", title: "Rest fat", unit: "g / lb", note: "", kind: .slider(min: 0.2, max: 0.6, step: 0.05), defaultValue: .number(d.restFatGramsPerLb)),
        ]

        // Coach
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        out += [
            DialSpec(key: .coachCheckInWeekday, group: .coach, title: "Check-in day", note: "The coach reviews the week on this day.", kind: .choice((1...7).map { DialChoice(String($0), weekdays[$0 - 1]) }), defaultValue: .choice(String(d.coachCheckInWeekday)), affectsTarget: false),
            DialSpec(key: .coachAutoApply, group: .coach, title: "Auto-apply", note: "Apply calorie recommendations without asking. Off means every change waits for Accept.", kind: .toggle, defaultValue: .bool(d.coachAutoApply), affectsTarget: false),
            DialSpec(key: .rateMissTolerancePercent, group: .coach, title: "Rate tolerance", unit: "% / wk", note: "How far the actual rate can miss the goal before the coach suggests a change.", kind: .slider(min: 0.05, max: 0.5, step: 0.05), defaultValue: .number(d.rateMissTolerancePercent), affectsTarget: false),
            DialSpec(key: .rateMissCheckIns, group: .coach, title: "Misses in a row", unit: "check-ins", note: "The rate must miss at this many check-ins in a row.", kind: .slider(min: 1, max: 4, step: 1), defaultValue: .number(Double(d.rateMissCheckIns)), affectsTarget: false),
            DialSpec(key: .coachMaxChangeKcal, group: .coach, title: "Max change", unit: "kcal", note: "The largest single calorie change the coach will suggest.", kind: .slider(min: 50, max: 500, step: 10), defaultValue: .number(d.coachMaxChangeKcal), affectsTarget: false),
            DialSpec(key: .minLoggedDaysPerWeek, group: .coach, title: "Logged days needed", unit: "days", note: "Below this the coach holds calorie changes until the data is complete.", kind: .slider(min: 3, max: 7, step: 1), defaultValue: .number(Double(d.minLoggedDaysPerWeek)), affectsTarget: false),
            DialSpec(key: .strengthDropPercent, group: .coach, title: "Strength drop", unit: "%", note: "An estimated 1RM falling this much counts as a drop.", kind: .slider(min: 2, max: 15, step: 0.5), defaultValue: .number(d.strengthDropPercent), affectsTarget: false),
            DialSpec(key: .strengthDropLifts, group: .coach, title: "Lifts dropping", unit: "lifts", note: "How many main lifts must drop before the coach reacts.", kind: .slider(min: 1, max: 6, step: 1), defaultValue: .number(Double(d.strengthDropLifts)), affectsTarget: false),
            DialSpec(key: .strengthDropWeeks, group: .coach, title: "Strength window", unit: "weeks", note: "Over how many weeks the drop is measured.", kind: .slider(min: 2, max: 8, step: 1), defaultValue: .number(Double(d.strengthDropWeeks)), affectsTarget: false),
            DialSpec(key: .strengthSlowRatePercent, group: .coach, title: "Slow the deficit by", unit: "% / wk", note: "How much the coach eases the cut when strength drops.", kind: .slider(min: 0.1, max: 0.5, step: 0.05), defaultValue: .number(d.strengthSlowRatePercent), affectsTarget: false),
            DialSpec(key: .longCutWeeks, group: .coach, title: "Long cut", unit: "weeks", note: "After this many weeks in a deficit the coach suggests maintenance.", kind: .slider(min: 6, max: 24, step: 1), defaultValue: .number(Double(d.longCutWeeks)), affectsTarget: false),
            DialSpec(key: .hardSetsTargetPerWeek, group: .coach, title: "Hard sets per muscle", unit: "sets / wk", note: "The weekly target on Progress, and the undertrained threshold while bulking.", kind: .slider(min: 4, max: 25, step: 1), defaultValue: .number(Double(d.hardSetsTargetPerWeek)), affectsTarget: false),
            DialSpec(key: .undertrainedWeeks, group: .coach, title: "Undertrained for", unit: "weeks", note: "Weeks under the set target before the coach flags a muscle.", kind: .slider(min: 1, max: 6, step: 1), defaultValue: .number(Double(d.undertrainedWeeks)), affectsTarget: false),
            DialSpec(key: .proteinHitDaysPerWeek, group: .coach, title: "Protein days", unit: "days / wk", note: "Days the protein target must be hit each week.", kind: .slider(min: 3, max: 7, step: 1), defaultValue: .number(Double(d.proteinHitDaysPerWeek)), affectsTarget: false),
            DialSpec(key: .stepsDropPercent, group: .coach, title: "Steps drift", unit: "%", note: "A weekly step drop this large from your window average is flagged.", kind: .slider(min: 5, max: 50, step: 5), defaultValue: .number(d.stepsDropPercent), affectsTarget: false),
            DialSpec(key: .bodyFatCeilingPercent, group: .coach, title: "Body fat ceiling", unit: "%", note: "Above this during a bulk, the coach suggests a cut.", kind: .slider(min: 8, max: 35, step: 0.5), defaultValue: .number(d.bodyFatCeilingPercent), affectsTarget: false),
        ]

        // Progress
        out += [
            DialSpec(key: .muscleUnlockWeeks, group: .progress, title: "Muscle unlock", unit: "weeks", note: "A muscle shows after this many weeks of sessions that train it.", kind: .slider(min: 1, max: 8, step: 1), defaultValue: .number(Double(d.muscleUnlockWeeks)), affectsTarget: false),
            DialSpec(key: .exerciseUnlockSessions, group: .progress, title: "Exercise unlock", unit: "sessions", note: "An exercise's 1RM trend shows after this many sessions.", kind: .slider(min: 2, max: 12, step: 1), defaultValue: .number(Double(d.exerciseUnlockSessions)), affectsTarget: false),
        ]

        // Display
        out += [
            DialSpec(key: .roundingKcal, group: .display, title: "Rounding", unit: "kcal", note: "Targets are rounded to the nearest step.", kind: .choice([DialChoice("1", "1"), DialChoice("5", "5"), DialChoice("10", "10"), DialChoice("25", "25"), DialChoice("50", "50")]), defaultValue: .choice(String(d.roundingKcal))),
            DialSpec(key: .waterOzPerLb, group: .display, row: "display.water", title: "Water per lb", unit: "oz / lb", note: "Base water target per pound of bodyweight.", kind: .slider(min: 0.3, max: 1.0, step: 0.05), defaultValue: .number(d.waterOzPerLb), affectsTarget: false),
            DialSpec(key: .waterOzPerTrainingHour, group: .display, row: "display.water", title: "Water per training hour", unit: "oz / h", note: "Added for each hour of training.", kind: .slider(min: 0, max: 32, step: 1), defaultValue: .number(d.waterOzPerTrainingHour), affectsTarget: false),
        ]

        return out
    }

    public static func spec(for key: DialKey, in dials: Dials) -> DialSpec? {
        specs(for: dials).first { $0.key == key }
    }

    /// Distinct spec-table rows in the core groups. This is the "35 dials" count.
    public static func coreRowCount(for dials: Dials) -> Int {
        Set(specs(for: dials).filter { DialGroup.coreGroups.contains($0.group) }.map(\.row)).count
    }

    /// Rows in the core groups where any value differs from its default.
    public static func changedCoreRows(in dials: Dials) -> [String] {
        var rows: [String] = []
        for spec in specs(for: dials) where DialGroup.coreGroups.contains(spec.group) {
            if dials.value(for: spec.key) != spec.defaultValue, !rows.contains(spec.row) {
                rows.append(spec.row)
            }
        }
        return rows
    }
}

// MARK: - Generic get and set

public extension Dials {

    func value(for key: DialKey) -> DialValue {
        if key.rawValue.hasPrefix(DialKey.liftMETPrefix) {
            let name = String(key.rawValue.dropFirst(DialKey.liftMETPrefix.count))
            return .number(liftStyles.first(where: { $0.name == name })?.met ?? 0)
        }
        if key.rawValue.hasPrefix(DialKey.cardioMETPrefix) {
            let name = String(key.rawValue.dropFirst(DialKey.cardioMETPrefix.count))
            return .number(cardioTypes.first(where: { $0.name == name })?.met ?? 0)
        }
        switch key {
        case .sex: return .choice(sex.rawValue)
        case .birthDate: return .date(birthDate)
        case .heightCm: return .optionalNumber(heightCm)
        case .phase: return .choice(phase.rawValue)
        case .phaseStartDate: return .date(phaseStartDate)

        case .weightSource: return .choice(weightSource.rawValue)
        case .manualWeightLb: return .optionalNumber(manualWeightLb)
        case .trendAlpha: return .number(trendAlpha)
        case .outlierThresholdLb: return .optionalNumber(outlierThresholdLb)
        case .bodyFatSource: return .choice(bodyFatSource.rawValue)
        case .bodyFatPercentManual: return .optionalNumber(bodyFatPercentManual)

        case .bmrFormula: return .choice(bmrFormula.rawValue)
        case .bmrWeightMifflin: return .number(bmrWeights.mifflin)
        case .bmrWeightKatch: return .number(bmrWeights.katchMcArdle)
        case .bmrWeightCunningham: return .number(bmrWeights.cunningham)
        case .bmrWeightHarris: return .number(bmrWeights.harrisBenedict)
        case .measuredRMR: return .optionalNumber(measuredRMR)
        case .bmrAdjustmentPercent: return .number(bmrAdjustmentPercent)

        case .activitySource: return .choice(activitySource.rawValue)
        case .activityBlendWatchShare: return .number(activityBlendWatchShare)
        case .watchCorrection: return .number(watchCorrection)
        case .dailyLivingPercent: return .number(dailyLivingPercent)
        case .stepCost: return .number(stepCostKcalPerStepPerKg)
        case .defaultLiftStyle: return .choice(defaultLiftStyle)
        case .liftDurationSource: return .choice(liftDurationSource.rawValue)
        case .fixedLiftMinutes: return .number(fixedLiftMinutes)
        case .postWorkoutBurnPercent: return .number(postWorkoutBurnPercent)

        case .tefMode: return .choice(tefMode.rawValue)
        case .tefProteinPercent: return .number(tefProteinPercent)
        case .tefCarbPercent: return .number(tefCarbPercent)
        case .tefFatPercent: return .number(tefFatPercent)
        case .tefFlatPercent: return .number(tefFlatPercent)

        case .trustWindowDays: return .number(Double(trustWindowDays))
        case .minDaysBeforeTrust: return .number(Double(minDaysBeforeTrust))
        case .maxTrustPercent: return .number(maxTrustPercent)
        case .kcalPerLb: return .number(kcalPerLb)
        case .incompleteFoodDays: return .choice(incompleteFoodDays.rawValue)
        case .metabolicAdaptationPercent: return .number(metabolicAdaptationPercent)

        case .rateMode: return .choice(rateMode.rawValue)
        case .ratePercentPerWeek: return .number(ratePercentPerWeek)
        case .rateLbPerWeek: return .number(rateLbPerWeek)
        case .fixedKcalOffset: return .number(fixedKcalOffset)
        case .goalWeightLb: return .optionalNumber(goalWeightLb)
        case .goalDate: return .date(goalDate)
        case .calorieFloor: return .optionalNumber(calorieFloor)
        case .calorieCeiling: return .optionalNumber(calorieCeiling)

        case .cyclingEnabled: return .bool(cyclingEnabled)
        case .cyclingShiftPercent: return .number(cyclingShiftPercent)
        case .trainingDayDetection: return .choice(trainingDayDetection.rawValue)
        case .scheduledTrainingWeekdays: return .intList(scheduledTrainingWeekdays)
        case .weekdayOffsets: return .numberList(weekdayOffsets)

        case .proteinGramsPerLb: return .number(proteinGramsPerLb)
        case .proteinBasis: return .choice(proteinBasis.rawValue)
        case .fatMode: return .choice(fatMode.rawValue)
        case .fatGramsPerLb: return .number(fatGramsPerLb)
        case .fatPercentOfCalories: return .number(fatPercentOfCalories)
        case .carbFloorGrams: return .number(carbFloorGrams)
        case .fiberGramsPer1000Kcal: return .number(fiberGramsPer1000Kcal)
        case .dayTypeOverridesEnabled: return .bool(dayTypeOverridesEnabled)
        case .trainingProteinGramsPerLb: return .number(trainingProteinGramsPerLb)
        case .trainingFatGramsPerLb: return .number(trainingFatGramsPerLb)
        case .restProteinGramsPerLb: return .number(restProteinGramsPerLb)
        case .restFatGramsPerLb: return .number(restFatGramsPerLb)

        case .coachCheckInWeekday: return .choice(String(coachCheckInWeekday))
        case .coachAutoApply: return .bool(coachAutoApply)
        case .rateMissTolerancePercent: return .number(rateMissTolerancePercent)
        case .rateMissCheckIns: return .number(Double(rateMissCheckIns))
        case .coachMaxChangeKcal: return .number(coachMaxChangeKcal)
        case .minLoggedDaysPerWeek: return .number(Double(minLoggedDaysPerWeek))
        case .strengthDropPercent: return .number(strengthDropPercent)
        case .strengthDropLifts: return .number(Double(strengthDropLifts))
        case .strengthDropWeeks: return .number(Double(strengthDropWeeks))
        case .strengthSlowRatePercent: return .number(strengthSlowRatePercent)
        case .longCutWeeks: return .number(Double(longCutWeeks))
        case .hardSetsTargetPerWeek: return .number(Double(hardSetsTargetPerWeek))
        case .undertrainedWeeks: return .number(Double(undertrainedWeeks))
        case .proteinHitDaysPerWeek: return .number(Double(proteinHitDaysPerWeek))
        case .stepsDropPercent: return .number(stepsDropPercent)
        case .bodyFatCeilingPercent: return .number(bodyFatCeilingPercent)

        case .muscleUnlockWeeks: return .number(Double(muscleUnlockWeeks))
        case .exerciseUnlockSessions: return .number(Double(exerciseUnlockSessions))

        case .roundingKcal: return .choice(String(roundingKcal))
        case .waterOzPerLb: return .number(waterOzPerLb)
        case .waterOzPerTrainingHour: return .number(waterOzPerTrainingHour)
        default: return .number(0)
        }
    }

    /// Applies a value. Values of the wrong shape are ignored, so a stale change log can't corrupt the dials.
    mutating func set(_ value: DialValue, for key: DialKey) {
        func num() -> Double? { value.doubleValue }
        func int() -> Int? { value.doubleValue.map { Int($0.rounded()) } }
        func optNum() -> Double?? {
            switch value {
            case .optionalNumber(let v): return .some(v)
            case .number(let v): return .some(v)
            default: return nil
            }
        }
        func choice<T: RawRepresentable>(_: T.Type) -> T? where T.RawValue == String {
            value.choiceValue.flatMap(T.init(rawValue:))
        }
        func date() -> Date?? {
            if case .date(let d) = value { return .some(d) }
            return nil
        }

        if key.rawValue.hasPrefix(DialKey.liftMETPrefix) {
            let name = String(key.rawValue.dropFirst(DialKey.liftMETPrefix.count))
            if let v = num(), let i = liftStyles.firstIndex(where: { $0.name == name }) { liftStyles[i].met = v }
            return
        }
        if key.rawValue.hasPrefix(DialKey.cardioMETPrefix) {
            let name = String(key.rawValue.dropFirst(DialKey.cardioMETPrefix.count))
            if let v = num(), let i = cardioTypes.firstIndex(where: { $0.name == name }) { cardioTypes[i].met = v }
            return
        }

        switch key {
        case .sex: if let v = choice(Sex.self) { sex = v }
        case .birthDate: if let v = date() { birthDate = v }
        case .heightCm: if let v = optNum() { heightCm = v }
        case .phase: if let v = choice(Phase.self) { phase = v }
        case .phaseStartDate: if let v = date() { phaseStartDate = v }

        case .weightSource: if let v = choice(WeightSource.self) { weightSource = v }
        case .manualWeightLb: if let v = optNum() { manualWeightLb = v }
        case .trendAlpha: if let v = num() { trendAlpha = v }
        case .outlierThresholdLb: if let v = optNum() { outlierThresholdLb = v }
        case .bodyFatSource: if let v = choice(BodyFatSource.self) { bodyFatSource = v }
        case .bodyFatPercentManual: if let v = optNum() { bodyFatPercentManual = v }

        case .bmrFormula: if let v = choice(BMRFormula.self) { bmrFormula = v }
        case .bmrWeightMifflin: if let v = num() { bmrWeights.mifflin = v }
        case .bmrWeightKatch: if let v = num() { bmrWeights.katchMcArdle = v }
        case .bmrWeightCunningham: if let v = num() { bmrWeights.cunningham = v }
        case .bmrWeightHarris: if let v = num() { bmrWeights.harrisBenedict = v }
        case .measuredRMR: if let v = optNum() { measuredRMR = v }
        case .bmrAdjustmentPercent: if let v = num() { bmrAdjustmentPercent = v }

        case .activitySource: if let v = choice(ActivitySource.self) { activitySource = v }
        case .activityBlendWatchShare: if let v = num() { activityBlendWatchShare = v }
        case .watchCorrection: if let v = num() { watchCorrection = v }
        case .dailyLivingPercent: if let v = num() { dailyLivingPercent = v }
        case .stepCost: if let v = num() { stepCostKcalPerStepPerKg = v }
        case .defaultLiftStyle: if let v = value.choiceValue { defaultLiftStyle = v }
        case .liftDurationSource: if let v = choice(LiftDurationSource.self) { liftDurationSource = v }
        case .fixedLiftMinutes: if let v = num() { fixedLiftMinutes = v }
        case .postWorkoutBurnPercent: if let v = num() { postWorkoutBurnPercent = v }

        case .tefMode: if let v = choice(TEFMode.self) { tefMode = v }
        case .tefProteinPercent: if let v = num() { tefProteinPercent = v }
        case .tefCarbPercent: if let v = num() { tefCarbPercent = v }
        case .tefFatPercent: if let v = num() { tefFatPercent = v }
        case .tefFlatPercent: if let v = num() { tefFlatPercent = v }

        case .trustWindowDays: if let v = int() { trustWindowDays = v }
        case .minDaysBeforeTrust: if let v = int() { minDaysBeforeTrust = v }
        case .maxTrustPercent: if let v = num() { maxTrustPercent = v }
        case .kcalPerLb: if let v = num() { kcalPerLb = v }
        case .incompleteFoodDays: if let v = choice(IncompleteDaysPolicy.self) { incompleteFoodDays = v }
        case .metabolicAdaptationPercent: if let v = num() { metabolicAdaptationPercent = v }

        case .rateMode: if let v = choice(RateMode.self) { rateMode = v }
        case .ratePercentPerWeek: if let v = num() { ratePercentPerWeek = v }
        case .rateLbPerWeek: if let v = num() { rateLbPerWeek = v }
        case .fixedKcalOffset: if let v = num() { fixedKcalOffset = v }
        case .goalWeightLb: if let v = optNum() { goalWeightLb = v }
        case .goalDate: if let v = date() { goalDate = v }
        case .calorieFloor: if let v = optNum() { calorieFloor = v }
        case .calorieCeiling: if let v = optNum() { calorieCeiling = v }

        case .cyclingEnabled: if let v = value.boolValue { cyclingEnabled = v }
        case .cyclingShiftPercent: if let v = num() { cyclingShiftPercent = v }
        case .trainingDayDetection: if let v = choice(TrainingDayDetection.self) { trainingDayDetection = v }
        case .scheduledTrainingWeekdays: if case .intList(let l) = value { scheduledTrainingWeekdays = l.filter { (1...7).contains($0) } }
        case .weekdayOffsets: if case .numberList(let l) = value, l.count == 7 { weekdayOffsets = l }

        case .proteinGramsPerLb: if let v = num() { proteinGramsPerLb = v }
        case .proteinBasis: if let v = choice(ProteinBasis.self) { proteinBasis = v }
        case .fatMode: if let v = choice(FatMode.self) { fatMode = v }
        case .fatGramsPerLb: if let v = num() { fatGramsPerLb = v }
        case .fatPercentOfCalories: if let v = num() { fatPercentOfCalories = v }
        case .carbFloorGrams: if let v = num() { carbFloorGrams = v }
        case .fiberGramsPer1000Kcal: if let v = num() { fiberGramsPer1000Kcal = v }
        case .dayTypeOverridesEnabled: if let v = value.boolValue { dayTypeOverridesEnabled = v }
        case .trainingProteinGramsPerLb: if let v = num() { trainingProteinGramsPerLb = v }
        case .trainingFatGramsPerLb: if let v = num() { trainingFatGramsPerLb = v }
        case .restProteinGramsPerLb: if let v = num() { restProteinGramsPerLb = v }
        case .restFatGramsPerLb: if let v = num() { restFatGramsPerLb = v }

        case .coachCheckInWeekday: if let s = value.choiceValue, let v = Int(s) { coachCheckInWeekday = v }
        case .coachAutoApply: if let v = value.boolValue { coachAutoApply = v }
        case .rateMissTolerancePercent: if let v = num() { rateMissTolerancePercent = v }
        case .rateMissCheckIns: if let v = int() { rateMissCheckIns = v }
        case .coachMaxChangeKcal: if let v = num() { coachMaxChangeKcal = v }
        case .minLoggedDaysPerWeek: if let v = int() { minLoggedDaysPerWeek = v }
        case .strengthDropPercent: if let v = num() { strengthDropPercent = v }
        case .strengthDropLifts: if let v = int() { strengthDropLifts = v }
        case .strengthDropWeeks: if let v = int() { strengthDropWeeks = v }
        case .strengthSlowRatePercent: if let v = num() { strengthSlowRatePercent = v }
        case .longCutWeeks: if let v = int() { longCutWeeks = v }
        case .hardSetsTargetPerWeek: if let v = int() { hardSetsTargetPerWeek = v }
        case .undertrainedWeeks: if let v = int() { undertrainedWeeks = v }
        case .proteinHitDaysPerWeek: if let v = int() { proteinHitDaysPerWeek = v }
        case .stepsDropPercent: if let v = num() { stepsDropPercent = v }
        case .bodyFatCeilingPercent: if let v = num() { bodyFatCeilingPercent = v }

        case .muscleUnlockWeeks: if let v = int() { muscleUnlockWeeks = v }
        case .exerciseUnlockSessions: if let v = int() { exerciseUnlockSessions = v }

        case .roundingKcal: if let s = value.choiceValue, let v = Int(s) { roundingKcal = v }
        case .waterOzPerLb: if let v = num() { waterOzPerLb = v }
        case .waterOzPerTrainingHour: if let v = num() { waterOzPerTrainingHour = v }
        default: break
        }
    }

    /// Resets one dial to its default.
    mutating func reset(_ key: DialKey) {
        guard let spec = DialCatalog.spec(for: key, in: self) else { return }
        set(spec.defaultValue, for: key)
    }

    func isDefault(_ key: DialKey) -> Bool {
        guard let spec = DialCatalog.spec(for: key, in: self) else { return true }
        return value(for: key) == spec.defaultValue
    }

    /// Returns a copy with one dial changed.
    func with(_ key: DialKey, _ value: DialValue) -> Dials {
        var copy = self
        copy.set(value, for: key)
        return copy
    }
}
