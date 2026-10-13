import Foundation

// MARK: - Enumerated choices

public enum Sex: String, Codable, CaseIterable, Sendable {
    case male, female
}

public enum WeightSource: String, Codable, CaseIterable, Sendable {
    case trend, latest, manual
}

public enum BodyFatSource: String, Codable, CaseIterable, Sendable {
    case manual, health, none
}

public enum BMRFormula: String, Codable, CaseIterable, Sendable {
    case average, mifflin, katchMcArdle, cunningham, harrisBenedict, weighted
}

public enum ActivitySource: String, Codable, CaseIterable, Sendable {
    case modeled, watch, blend
}

public enum LiftDurationSource: String, Codable, CaseIterable, Sendable {
    case workouts, fixed
}

public enum TEFMode: String, Codable, CaseIterable, Sendable {
    case byMacro, flat
}

public enum IncompleteDaysPolicy: String, Codable, CaseIterable, Sendable {
    case exclude, include
}

public enum Phase: String, Codable, CaseIterable, Sendable {
    case cut, recomp, maintain, leanBulk, bulk

    public var title: String {
        switch self {
        case .cut: return "Cut"
        case .recomp: return "Recomp"
        case .maintain: return "Maintain"
        case .leanBulk: return "Lean bulk"
        case .bulk: return "Bulk"
        }
    }

    /// Default rate in % bodyweight per week when the phase is chosen.
    public var defaultRatePercent: Double {
        switch self {
        case .cut: return -0.50
        case .recomp: return 0.0
        case .maintain: return 0.0
        case .leanBulk: return 0.30
        case .bulk: return 0.50
        }
    }

    /// Usual rate range (% bodyweight per week) shown as a caption on Plan.
    public var usualRange: ClosedRange<Double> {
        switch self {
        case .cut: return -1.0 ... -0.5
        case .recomp: return -0.25 ... 0.0
        case .maintain: return -0.1 ... 0.1
        case .leanBulk: return 0.25 ... 0.5
        case .bulk: return 0.5 ... 1.0
        }
    }

    public var isDeficit: Bool { self == .cut }
    public var isSurplus: Bool { self == .leanBulk || self == .bulk }
}

public enum RateMode: String, Codable, CaseIterable, Sendable {
    case percentPerWeek, lbPerWeek, fixedKcal, goalWeightByDate
}

public enum TrainingDayDetection: String, Codable, CaseIterable, Sendable {
    case workout, schedule, manual
}

public enum ProteinBasis: String, Codable, CaseIterable, Sendable {
    case bodyweight, leanMass, goalWeight
}

public enum FatMode: String, Codable, CaseIterable, Sendable {
    case gramsPerLb, percentOfCalories
}

/// A named MET value, used for both lifting styles and cardio types.
public struct MetEntry: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var met: Double

    public init(name: String, met: Double) {
        self.name = name
        self.met = met
    }
}

/// Weights for the weighted-blend BMR mode. Normalised at use.
public struct BMRWeights: Codable, Equatable, Sendable {
    public var mifflin: Double
    public var katchMcArdle: Double
    public var cunningham: Double
    public var harrisBenedict: Double

    public init(mifflin: Double = 1, katchMcArdle: Double = 1, cunningham: Double = 0, harrisBenedict: Double = 0) {
        self.mifflin = mifflin
        self.katchMcArdle = katchMcArdle
        self.cunningham = cunningham
        self.harrisBenedict = harrisBenedict
    }
}

// MARK: - Dials

/// Every constant the engine uses. One active set, Codable and versioned.
/// Dials added in a later version decode to their default so old saves keep working.
public struct Dials: Codable, Equatable, Sendable {

    public static let currentVersion = 1

    public var version: Int = Dials.currentVersion

    // MARK: Body basics
    public var sex: Sex = .male
    public var birthDate: Date? = nil
    public var heightCm: Double? = nil
    public var bodyFatPercentManual: Double? = nil
    public var phase: Phase = .leanBulk
    public var phaseStartDate: Date? = nil

    // MARK: Body
    public var weightSource: WeightSource = .trend
    public var manualWeightLb: Double? = nil
    public var trendAlpha: Double = 0.10
    /// Ignore weigh-ins this many lb off the trend. `nil` turns the filter off.
    public var outlierThresholdLb: Double? = 3
    public var bodyFatSource: BodyFatSource = .manual

    // MARK: BMR
    public var bmrFormula: BMRFormula = .average
    public var bmrWeights: BMRWeights = BMRWeights()
    public var measuredRMR: Double? = nil
    public var bmrAdjustmentPercent: Double = 0

    // MARK: Activity
    public var activitySource: ActivitySource = .modeled
    /// Share of the Watch estimate when `activitySource == .blend` (0 = all modeled, 1 = all Watch).
    public var activityBlendWatchShare: Double = 0.5
    public var watchCorrection: Double = 0.85
    public var dailyLivingPercent: Double = 10
    public var stepCostKcalPerStepPerKg: Double = 0.0005
    public var liftStyles: [MetEntry] = Dials.defaultLiftStyles
    public var defaultLiftStyle: String = "Hypertrophy"
    public var liftDurationSource: LiftDurationSource = .workouts
    public var fixedLiftMinutes: Double = 60
    public var postWorkoutBurnPercent: Double = 0
    public var cardioTypes: [MetEntry] = Dials.defaultCardioTypes

    // MARK: Digestion
    public var tefMode: TEFMode = .byMacro
    public var tefProteinPercent: Double = 25
    public var tefCarbPercent: Double = 7.5
    public var tefFatPercent: Double = 2
    public var tefFlatPercent: Double = 10

    // MARK: Adaptive
    public var trustWindowDays: Int = 21
    public var minDaysBeforeTrust: Int = 7
    public var maxTrustPercent: Double = 90
    public var kcalPerLb: Double = 3500
    public var incompleteFoodDays: IncompleteDaysPolicy = .exclude
    public var metabolicAdaptationPercent: Double = 0

    // MARK: Goal
    public var rateMode: RateMode = .percentPerWeek
    public var ratePercentPerWeek: Double = 0.30
    public var rateLbPerWeek: Double = 0.5
    public var fixedKcalOffset: Double = 300
    public var goalWeightLb: Double? = nil
    public var goalDate: Date? = nil
    public var calorieFloor: Double? = nil
    public var calorieCeiling: Double? = nil
    /// A scheduled diet break: the rate is held at zero for `dietBreakWeeks` from this date.
    public var dietBreakStartDate: Date? = nil
    public var dietBreakWeeks: Int = 1

    // MARK: Cycling
    public var cyclingEnabled: Bool = true
    public var cyclingShiftPercent: Double = 100
    public var trainingDayDetection: TrainingDayDetection = .workout
    /// Weekdays (1 = Sunday … 7 = Saturday) that count as training days in schedule mode.
    public var scheduledTrainingWeekdays: [Int] = [2, 3, 5, 6]
    /// kcal added on each weekday, index 0 = Sunday … 6 = Saturday.
    public var weekdayOffsets: [Double] = [0, 0, 0, 0, 0, 0, 0]

    // MARK: Macros
    public var proteinGramsPerLb: Double = 1.0
    public var proteinBasis: ProteinBasis = .bodyweight
    public var fatMode: FatMode = .gramsPerLb
    public var fatGramsPerLb: Double = 0.35
    public var fatPercentOfCalories: Double = 25
    public var carbFloorGrams: Double = 50
    public var fiberGramsPer1000Kcal: Double = 14
    public var dayTypeOverridesEnabled: Bool = false
    public var trainingProteinGramsPerLb: Double = 1.0
    public var trainingFatGramsPerLb: Double = 0.35
    public var restProteinGramsPerLb: Double = 1.0
    public var restFatGramsPerLb: Double = 0.35

    // MARK: Coach
    /// Weekday of the check-in, 1 = Sunday … 7 = Saturday.
    public var coachCheckInWeekday: Int = 1
    public var coachAutoApply: Bool = false
    public var rateMissTolerancePercent: Double = 0.15
    public var rateMissCheckIns: Int = 2
    public var coachMaxChangeKcal: Double = 250
    public var minLoggedDaysPerWeek: Int = 5
    public var strengthDropPercent: Double = 5
    public var strengthDropLifts: Int = 3
    public var strengthDropWeeks: Int = 4
    public var strengthSlowRatePercent: Double = 0.25
    public var longCutWeeks: Int = 12
    public var hardSetsTargetPerWeek: Int = 10
    public var undertrainedWeeks: Int = 3
    public var proteinHitDaysPerWeek: Int = 5
    public var stepsDropPercent: Double = 20
    public var bodyFatCeilingPercent: Double = 18

    // MARK: Progress
    public var muscleUnlockWeeks: Int = 4
    public var exerciseUnlockSessions: Int = 6

    // MARK: Display
    public var roundingKcal: Int = 10
    public var waterOzPerLb: Double = 0.5
    public var waterOzPerTrainingHour: Double = 12

    public init() {}

    public static let defaultLiftStyles: [MetEntry] = [
        MetEntry(name: "Heavy", met: 3.5),
        MetEntry(name: "Hypertrophy", met: 5.0),
        MetEntry(name: "Supersets", met: 6.0),
    ]

    public static let defaultCardioTypes: [MetEntry] = [
        MetEntry(name: "Walk", met: 5.0),
        MetEntry(name: "Bike", met: 7.0),
        MetEntry(name: "Stairs", met: 9.0),
        MetEntry(name: "Run", met: 9.8),
        MetEntry(name: "HIIT", met: 8.0),
    ]

    // MARK: Lookups

    public func met(forLiftStyle name: String?) -> Double {
        let wanted = (name ?? defaultLiftStyle).lowercased()
        if let entry = liftStyles.first(where: { $0.name.lowercased() == wanted }) { return entry.met }
        if let entry = liftStyles.first(where: { $0.name.lowercased() == defaultLiftStyle.lowercased() }) { return entry.met }
        return liftStyles.first?.met ?? 5.0
    }

    public func met(forCardioType name: String?) -> Double {
        let wanted = (name ?? "").lowercased()
        if let entry = cardioTypes.first(where: { $0.name.lowercased() == wanted }) { return entry.met }
        // Unknown cardio: a middle-of-the-road value.
        return 6.0
    }

    /// The diet break's last day (exclusive), if one is scheduled.
    public func dietBreakEnd(calendar: Calendar = .current) -> Date? {
        guard let start = dietBreakStartDate else { return nil }
        return calendar.date(byAdding: .day, value: max(1, dietBreakWeeks) * 7, to: calendar.startOfDay(for: start))
    }

    public func isInDietBreak(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let start = dietBreakStartDate, let end = dietBreakEnd(calendar: calendar) else { return false }
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day < end
    }

    public func weekdayOffset(forWeekday weekday: Int) -> Double {
        let index = max(0, min(6, weekday - 1))
        return index < weekdayOffsets.count ? weekdayOffsets[index] : 0
    }

    // MARK: Codable (versioned, every key optional)

    enum CodingKeys: String, CodingKey {
        case version
        case sex, birthDate, heightCm, bodyFatPercentManual, phase, phaseStartDate
        case weightSource, manualWeightLb, trendAlpha, outlierThresholdLb, bodyFatSource
        case bmrFormula, bmrWeights, measuredRMR, bmrAdjustmentPercent
        case activitySource, activityBlendWatchShare, watchCorrection, dailyLivingPercent, stepCostKcalPerStepPerKg
        case liftStyles, defaultLiftStyle, liftDurationSource, fixedLiftMinutes, postWorkoutBurnPercent, cardioTypes
        case tefMode, tefProteinPercent, tefCarbPercent, tefFatPercent, tefFlatPercent
        case trustWindowDays, minDaysBeforeTrust, maxTrustPercent, kcalPerLb, incompleteFoodDays, metabolicAdaptationPercent
        case rateMode, ratePercentPerWeek, rateLbPerWeek, fixedKcalOffset, goalWeightLb, goalDate, calorieFloor, calorieCeiling
        case dietBreakStartDate, dietBreakWeeks
        case cyclingEnabled, cyclingShiftPercent, trainingDayDetection, scheduledTrainingWeekdays, weekdayOffsets
        case proteinGramsPerLb, proteinBasis, fatMode, fatGramsPerLb, fatPercentOfCalories, carbFloorGrams, fiberGramsPer1000Kcal
        case dayTypeOverridesEnabled, trainingProteinGramsPerLb, trainingFatGramsPerLb, restProteinGramsPerLb, restFatGramsPerLb
        case coachCheckInWeekday, coachAutoApply, rateMissTolerancePercent, rateMissCheckIns, coachMaxChangeKcal, minLoggedDaysPerWeek
        case strengthDropPercent, strengthDropLifts, strengthDropWeeks, strengthSlowRatePercent, longCutWeeks
        case hardSetsTargetPerWeek, undertrainedWeeks, proteinHitDaysPerWeek, stepsDropPercent, bodyFatCeilingPercent
        case muscleUnlockWeeks, exerciseUnlockSessions
        case roundingKcal, waterOzPerLb, waterOzPerTrainingHour
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Dials()
        version = Dials.currentVersion

        sex = c.value(.sex, default: d.sex)
        birthDate = c.optional(.birthDate, default: d.birthDate)
        heightCm = c.optional(.heightCm, default: d.heightCm)
        bodyFatPercentManual = c.optional(.bodyFatPercentManual, default: d.bodyFatPercentManual)
        phase = c.value(.phase, default: d.phase)
        phaseStartDate = c.optional(.phaseStartDate, default: d.phaseStartDate)

        weightSource = c.value(.weightSource, default: d.weightSource)
        manualWeightLb = c.optional(.manualWeightLb, default: d.manualWeightLb)
        trendAlpha = c.value(.trendAlpha, default: d.trendAlpha)
        outlierThresholdLb = c.optional(.outlierThresholdLb, default: d.outlierThresholdLb)
        bodyFatSource = c.value(.bodyFatSource, default: d.bodyFatSource)

        bmrFormula = c.value(.bmrFormula, default: d.bmrFormula)
        bmrWeights = c.value(.bmrWeights, default: d.bmrWeights)
        measuredRMR = c.optional(.measuredRMR, default: d.measuredRMR)
        bmrAdjustmentPercent = c.value(.bmrAdjustmentPercent, default: d.bmrAdjustmentPercent)

        activitySource = c.value(.activitySource, default: d.activitySource)
        activityBlendWatchShare = c.value(.activityBlendWatchShare, default: d.activityBlendWatchShare)
        watchCorrection = c.value(.watchCorrection, default: d.watchCorrection)
        dailyLivingPercent = c.value(.dailyLivingPercent, default: d.dailyLivingPercent)
        stepCostKcalPerStepPerKg = c.value(.stepCostKcalPerStepPerKg, default: d.stepCostKcalPerStepPerKg)
        liftStyles = c.value(.liftStyles, default: d.liftStyles)
        defaultLiftStyle = c.value(.defaultLiftStyle, default: d.defaultLiftStyle)
        liftDurationSource = c.value(.liftDurationSource, default: d.liftDurationSource)
        fixedLiftMinutes = c.value(.fixedLiftMinutes, default: d.fixedLiftMinutes)
        postWorkoutBurnPercent = c.value(.postWorkoutBurnPercent, default: d.postWorkoutBurnPercent)
        cardioTypes = c.value(.cardioTypes, default: d.cardioTypes)

        tefMode = c.value(.tefMode, default: d.tefMode)
        tefProteinPercent = c.value(.tefProteinPercent, default: d.tefProteinPercent)
        tefCarbPercent = c.value(.tefCarbPercent, default: d.tefCarbPercent)
        tefFatPercent = c.value(.tefFatPercent, default: d.tefFatPercent)
        tefFlatPercent = c.value(.tefFlatPercent, default: d.tefFlatPercent)

        trustWindowDays = c.value(.trustWindowDays, default: d.trustWindowDays)
        minDaysBeforeTrust = c.value(.minDaysBeforeTrust, default: d.minDaysBeforeTrust)
        maxTrustPercent = c.value(.maxTrustPercent, default: d.maxTrustPercent)
        kcalPerLb = c.value(.kcalPerLb, default: d.kcalPerLb)
        incompleteFoodDays = c.value(.incompleteFoodDays, default: d.incompleteFoodDays)
        metabolicAdaptationPercent = c.value(.metabolicAdaptationPercent, default: d.metabolicAdaptationPercent)

        rateMode = c.value(.rateMode, default: d.rateMode)
        ratePercentPerWeek = c.value(.ratePercentPerWeek, default: d.ratePercentPerWeek)
        rateLbPerWeek = c.value(.rateLbPerWeek, default: d.rateLbPerWeek)
        fixedKcalOffset = c.value(.fixedKcalOffset, default: d.fixedKcalOffset)
        goalWeightLb = c.optional(.goalWeightLb, default: d.goalWeightLb)
        goalDate = c.optional(.goalDate, default: d.goalDate)
        calorieFloor = c.optional(.calorieFloor, default: d.calorieFloor)
        calorieCeiling = c.optional(.calorieCeiling, default: d.calorieCeiling)
        dietBreakStartDate = c.optional(.dietBreakStartDate, default: d.dietBreakStartDate)
        dietBreakWeeks = c.value(.dietBreakWeeks, default: d.dietBreakWeeks)

        cyclingEnabled = c.value(.cyclingEnabled, default: d.cyclingEnabled)
        cyclingShiftPercent = c.value(.cyclingShiftPercent, default: d.cyclingShiftPercent)
        trainingDayDetection = c.value(.trainingDayDetection, default: d.trainingDayDetection)
        scheduledTrainingWeekdays = c.value(.scheduledTrainingWeekdays, default: d.scheduledTrainingWeekdays)
        weekdayOffsets = c.value(.weekdayOffsets, default: d.weekdayOffsets)
        if weekdayOffsets.count != 7 { weekdayOffsets = d.weekdayOffsets }

        proteinGramsPerLb = c.value(.proteinGramsPerLb, default: d.proteinGramsPerLb)
        proteinBasis = c.value(.proteinBasis, default: d.proteinBasis)
        fatMode = c.value(.fatMode, default: d.fatMode)
        fatGramsPerLb = c.value(.fatGramsPerLb, default: d.fatGramsPerLb)
        fatPercentOfCalories = c.value(.fatPercentOfCalories, default: d.fatPercentOfCalories)
        carbFloorGrams = c.value(.carbFloorGrams, default: d.carbFloorGrams)
        fiberGramsPer1000Kcal = c.value(.fiberGramsPer1000Kcal, default: d.fiberGramsPer1000Kcal)
        dayTypeOverridesEnabled = c.value(.dayTypeOverridesEnabled, default: d.dayTypeOverridesEnabled)
        trainingProteinGramsPerLb = c.value(.trainingProteinGramsPerLb, default: d.trainingProteinGramsPerLb)
        trainingFatGramsPerLb = c.value(.trainingFatGramsPerLb, default: d.trainingFatGramsPerLb)
        restProteinGramsPerLb = c.value(.restProteinGramsPerLb, default: d.restProteinGramsPerLb)
        restFatGramsPerLb = c.value(.restFatGramsPerLb, default: d.restFatGramsPerLb)

        coachCheckInWeekday = c.value(.coachCheckInWeekday, default: d.coachCheckInWeekday)
        coachAutoApply = c.value(.coachAutoApply, default: d.coachAutoApply)
        rateMissTolerancePercent = c.value(.rateMissTolerancePercent, default: d.rateMissTolerancePercent)
        rateMissCheckIns = c.value(.rateMissCheckIns, default: d.rateMissCheckIns)
        coachMaxChangeKcal = c.value(.coachMaxChangeKcal, default: d.coachMaxChangeKcal)
        minLoggedDaysPerWeek = c.value(.minLoggedDaysPerWeek, default: d.minLoggedDaysPerWeek)
        strengthDropPercent = c.value(.strengthDropPercent, default: d.strengthDropPercent)
        strengthDropLifts = c.value(.strengthDropLifts, default: d.strengthDropLifts)
        strengthDropWeeks = c.value(.strengthDropWeeks, default: d.strengthDropWeeks)
        strengthSlowRatePercent = c.value(.strengthSlowRatePercent, default: d.strengthSlowRatePercent)
        longCutWeeks = c.value(.longCutWeeks, default: d.longCutWeeks)
        hardSetsTargetPerWeek = c.value(.hardSetsTargetPerWeek, default: d.hardSetsTargetPerWeek)
        undertrainedWeeks = c.value(.undertrainedWeeks, default: d.undertrainedWeeks)
        proteinHitDaysPerWeek = c.value(.proteinHitDaysPerWeek, default: d.proteinHitDaysPerWeek)
        stepsDropPercent = c.value(.stepsDropPercent, default: d.stepsDropPercent)
        bodyFatCeilingPercent = c.value(.bodyFatCeilingPercent, default: d.bodyFatCeilingPercent)

        muscleUnlockWeeks = c.value(.muscleUnlockWeeks, default: d.muscleUnlockWeeks)
        exerciseUnlockSessions = c.value(.exerciseUnlockSessions, default: d.exerciseUnlockSessions)

        roundingKcal = c.value(.roundingKcal, default: d.roundingKcal)
        waterOzPerLb = c.value(.waterOzPerLb, default: d.waterOzPerLb)
        waterOzPerTrainingHour = c.value(.waterOzPerTrainingHour, default: d.waterOzPerTrainingHour)
    }
}

private extension KeyedDecodingContainer {
    /// Decodes a value or falls back to the default when the key is missing or malformed.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// Optional fields: a missing key keeps the default, an explicit `null` means "off".
    func optional<T: Decodable>(_ key: Key, default fallback: T?) -> T? {
        guard contains(key) else { return fallback }
        return try? decodeIfPresent(T.self, forKey: key)
    }
}

// MARK: - Presets and change log

/// A name plus a full Dials snapshot. Export and import as JSON.
public struct DialsPreset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var created: Date
    public var dials: Dials

    public init(id: UUID = UUID(), name: String, created: Date = Date(), dials: Dials) {
        self.id = id
        self.name = name
        self.created = created
        self.dials = dials
    }
}

public extension Dials {
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }()

    static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func encodedJSON() throws -> Data {
        try Dials.jsonEncoder.encode(self)
    }

    static func decode(json: Data) throws -> Dials {
        try jsonDecoder.decode(Dials.self, from: json)
    }
}
