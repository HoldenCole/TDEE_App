import Foundation

public enum DayType: String, Codable, Sendable {
    case training, rest, weeklyAverage
}

/// Calories and macros for one kind of day.
public struct DayTargets: Equatable, Sendable {
    public var dayType: DayType
    public var calories: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var waterOz: Double
    public var carbsBelowFloor: Bool

    public init(dayType: DayType, calories: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double, waterOz: Double, carbsBelowFloor: Bool) {
        self.dayType = dayType
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.waterOz = waterOz
        self.carbsBelowFloor = carbsBelowFloor
    }
}

/// The goal expressed every way at once, from whichever rate mode is active.
public struct GoalRate: Equatable, Sendable {
    public let mode: RateMode
    public let lbPerWeek: Double
    public let percentPerWeek: Double
    /// Daily surplus (positive) or deficit (negative) in kcal.
    public let dailyKcal: Double

    public static func compute(dials: Dials, weightLb: Double, today: Date, calendar: Calendar) -> GoalRate {
        let w = max(weightLb, 1)
        var lb: Double
        var daily: Double? = nil
        switch dials.rateMode {
        case .percentPerWeek:
            lb = dials.ratePercentPerWeek / 100 * w
        case .lbPerWeek:
            lb = dials.rateLbPerWeek
        case .fixedKcal:
            daily = dials.fixedKcalOffset
            lb = dials.fixedKcalOffset * 7 / dials.kcalPerLb
        case .goalWeightByDate:
            if let goal = dials.goalWeightLb, let date = dials.goalDate {
                let days = max(7, calendar.days(from: today, to: date))
                lb = (goal - w) / (Double(days) / 7)
            } else {
                lb = 0
            }
        }
        let dailyKcal = daily ?? lb * dials.kcalPerLb / 7
        return GoalRate(mode: dials.rateMode, lbPerWeek: lb, percentPerWeek: lb / w * 100, dailyKcal: dailyKcal)
    }

    /// The dial value that would produce `lbPerWeek` in the active mode, for the coach to apply.
    public static func dialValue(forLbPerWeek lb: Double, dials: Dials, weightLb: Double) -> (key: DialKey, value: DialValue)? {
        switch dials.rateMode {
        case .percentPerWeek:
            return (.ratePercentPerWeek, .number((lb / max(weightLb, 1) * 100 * 100).rounded() / 100))
        case .lbPerWeek:
            return (.rateLbPerWeek, .number((lb * 100).rounded() / 100))
        case .fixedKcal:
            return (.fixedKcalOffset, .number((lb * dials.kcalPerLb / 7).rounded()))
        case .goalWeightByDate:
            return nil
        }
    }
}

public enum Macros {

    /// Macro targets for a calorie amount on a kind of day.
    public static func targets(calories: Double, dayType: DayType, weightLb: Double, leanMassLb: Double?, trainingHours: Double, dials: Dials) -> DayTargets {
        var proteinPerLb = dials.proteinGramsPerLb
        var fatPerLb = dials.fatGramsPerLb
        if dials.dayTypeOverridesEnabled {
            switch dayType {
            case .training:
                proteinPerLb = dials.trainingProteinGramsPerLb
                fatPerLb = dials.trainingFatGramsPerLb
            case .rest:
                proteinPerLb = dials.restProteinGramsPerLb
                fatPerLb = dials.restFatGramsPerLb
            case .weeklyAverage:
                break
            }
        }

        let basis: Double
        switch dials.proteinBasis {
        case .bodyweight: basis = weightLb
        case .leanMass: basis = leanMassLb ?? weightLb
        case .goalWeight: basis = dials.goalWeightLb ?? weightLb
        }
        let protein = (proteinPerLb * basis).rounded()

        let fat: Double
        switch dials.fatMode {
        case .gramsPerLb: fat = (fatPerLb * weightLb).rounded()
        case .percentOfCalories: fat = (calories * dials.fatPercentOfCalories / 100 / 9).rounded()
        }

        let carbsRaw = (calories - protein * 4 - fat * 9) / 4
        let carbs = max(0, carbsRaw.rounded())
        let fiber = (dials.fiberGramsPer1000Kcal * calories / 1000).rounded()
        let water = (dials.waterOzPerLb * weightLb + dials.waterOzPerTrainingHour * trainingHours).rounded()

        return DayTargets(dayType: dayType, calories: calories, proteinG: protein, carbsG: carbs, fatG: fat, fiberG: fiber, waterOz: water, carbsBelowFloor: carbsRaw < dials.carbFloorGrams)
    }
}

/// Everything about the calorie target, before the day-specific weekday offset.
public struct TargetsResult: Equatable, Sendable {
    /// Share of the observed TDEE in the blend, 0–1.
    public let trust: Double
    public let daysLogged: Int
    public let windowDays: Int
    public let observedTDEE: Double?
    public let formulaRest: Double
    public let formulaTraining: Double
    public let formulaWeeklyAverage: Double
    public let maintenance: Double
    public let goalRate: GoalRate
    public let liftDaysPerWeek: Double
    /// Maintenance plus the goal adjustment, clamped and rounded. The weekly average target.
    public let baseTarget: Double
    public let cyclingGap: Double
    public let rest: DayTargets
    public let training: DayTargets
    public let weeklyAverage: DayTargets
    public let hitFloor: Bool
    public let hitCeiling: Bool
    public let tef: Double

    public var trustPercent: Double { (trust * 100).rounded() }
}
