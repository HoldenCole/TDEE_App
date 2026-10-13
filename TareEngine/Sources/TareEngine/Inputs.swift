import Foundation

/// One cardio session on a day, by the type names in `Dials.cardioTypes`.
public struct CardioSession: Codable, Equatable, Hashable, Sendable {
    public var type: String
    public var minutes: Double

    public init(type: String, minutes: Double) {
        self.type = type
        self.minutes = minutes
    }
}

/// Everything the engine knows about one calendar day. The app builds these from its
/// `DayRecord` store; the engine never sees SwiftData.
public struct DayInput: Codable, Equatable, Identifiable, Sendable {
    public var id: Date { date }

    public var date: Date
    public var weightLb: Double?
    public var bodyFatPercent: Double?
    public var leanMassLb: Double?
    public var calories: Double?
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var waterOz: Double?
    public var steps: Int?
    public var activeEnergyKcal: Double?
    public var liftMinutes: Double?
    public var liftStyle: String?
    public var cardioSessions: [CardioSession]
    /// False when the user marked the day's food log as incomplete.
    public var foodLogComplete: Bool
    /// The manual "Lifting today" toggle. `nil` means not set.
    public var liftingOverride: Bool?

    public init(date: Date,
                weightLb: Double? = nil,
                bodyFatPercent: Double? = nil,
                leanMassLb: Double? = nil,
                calories: Double? = nil,
                proteinG: Double? = nil,
                carbsG: Double? = nil,
                fatG: Double? = nil,
                waterOz: Double? = nil,
                steps: Int? = nil,
                activeEnergyKcal: Double? = nil,
                liftMinutes: Double? = nil,
                liftStyle: String? = nil,
                cardioSessions: [CardioSession] = [],
                foodLogComplete: Bool = true,
                liftingOverride: Bool? = nil) {
        self.date = date
        self.weightLb = weightLb
        self.bodyFatPercent = bodyFatPercent
        self.leanMassLb = leanMassLb
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.waterOz = waterOz
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.liftMinutes = liftMinutes
        self.liftStyle = liftStyle
        self.cardioSessions = cardioSessions
        self.foodLogComplete = foodLogComplete
        self.liftingOverride = liftingOverride
    }

    public var hasLift: Bool { (liftMinutes ?? 0) > 0 }

    public var totalCardioMinutes: Double { cardioSessions.reduce(0) { $0 + $1.minutes } }

    /// Whether this day's calories count toward the observed TDEE under the given policy.
    public func countsForIntake(policy: IncompleteDaysPolicy) -> Bool {
        guard calories != nil else { return false }
        return foodLogComplete || policy == .include
    }
}

public enum SetType: String, Codable, CaseIterable, Sendable {
    case warmup, working, drop, failure

    public var isWorking: Bool { self != .warmup }
}

/// One set from Hevy, Strong or a spreadsheet.
public struct LiftSetInput: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(date.timeIntervalSince1970)-\(exercise)-\(setIndex)" }

    public var date: Date
    public var exercise: String
    public var setIndex: Int
    public var setType: SetType
    public var weightLb: Double
    public var reps: Int
    public var rpe: Double?
    public var source: String

    public init(date: Date, exercise: String, setIndex: Int, setType: SetType = .working, weightLb: Double, reps: Int, rpe: Double? = nil, source: String = "") {
        self.date = date
        self.exercise = exercise
        self.setIndex = setIndex
        self.setType = setType
        self.weightLb = weightLb
        self.reps = reps
        self.rpe = rpe
        self.source = source
    }
}
