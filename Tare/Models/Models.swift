import Foundation
import SwiftData
import TareEngine

// MARK: - DayRecord

/// One row per calendar date. Health, imports and manual edits all land here.
@Model
final class DayRecord {
    @Attribute(.unique) var date: Date
    var weightLb: Double?
    var bodyFatPercent: Double?
    var leanMassLb: Double?
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var waterOz: Double?
    var steps: Int?
    var activeEnergyKcal: Double?
    var liftMinutes: Double?
    var liftStyle: String?
    var cardioSessions: [CardioSession]
    var foodLogComplete: Bool
    var liftingOverride: Bool?
    var lastSynced: Date?

    init(date: Date) {
        self.date = date
        self.cardioSessions = []
        self.foodLogComplete = true
    }

    var cardioMinutes: Double { cardioSessions.reduce(0) { $0 + $1.minutes } }

    var asInput: DayInput {
        DayInput(date: date, weightLb: weightLb, bodyFatPercent: bodyFatPercent, leanMassLb: leanMassLb, calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG, waterOz: waterOz, steps: steps, activeEnergyKcal: activeEnergyKcal, liftMinutes: liftMinutes, liftStyle: liftStyle, cardioSessions: cardioSessions, foodLogComplete: foodLogComplete, liftingOverride: liftingOverride)
    }

    /// Copies non-nil fields from an imported day.
    func merge(_ input: DayInput) {
        if let v = input.weightLb { weightLb = v }
        if let v = input.bodyFatPercent { bodyFatPercent = v }
        if let v = input.leanMassLb { leanMassLb = v }
        if let v = input.calories { calories = v }
        if let v = input.proteinG { proteinG = v }
        if let v = input.carbsG { carbsG = v }
        if let v = input.fatG { fatG = v }
        if let v = input.waterOz { waterOz = v }
        if let v = input.steps { steps = v }
        if let v = input.activeEnergyKcal { activeEnergyKcal = v }
        if let v = input.liftMinutes { liftMinutes = v }
        if let v = input.liftStyle { liftStyle = v }
        if !input.cardioSessions.isEmpty { cardioSessions = input.cardioSessions }
        if let v = input.liftingOverride { liftingOverride = v }
        foodLogComplete = input.foodLogComplete
    }
}

// MARK: - LiftSet

@Model
final class LiftSet {
    var date: Date
    var exercise: String
    var setIndex: Int
    var setTypeRaw: String
    var weightLb: Double
    var reps: Int
    var rpe: Double?
    var source: String
    /// Hevy workout ID or import file name, to avoid duplicates.
    var batchID: String?

    init(input: LiftSetInput, batchID: String? = nil) {
        self.date = input.date
        self.exercise = input.exercise
        self.setIndex = input.setIndex
        self.setTypeRaw = input.setType.rawValue
        self.weightLb = input.weightLb
        self.reps = input.reps
        self.rpe = input.rpe
        self.source = input.source
        self.batchID = batchID
    }

    var setType: SetType { SetType(rawValue: setTypeRaw) ?? .working }

    var asInput: LiftSetInput {
        LiftSetInput(date: date, exercise: exercise, setIndex: setIndex, setType: setType, weightLb: weightLb, reps: reps, rpe: rpe, source: source)
    }

    /// Stable key for de-duplication across syncs and imports.
    var dedupeKey: String { LiftSet.dedupeKey(for: asInput) }

    static func dedupeKey(for input: LiftSetInput) -> String {
        "\(Int(input.date.timeIntervalSince1970))|\(MuscleMap.normalize(input.exercise))|\(input.setIndex)"
    }
}

// MARK: - ExerciseMapEntry

/// The user's own muscle tags and anything a source told us. Built-in rules live in the engine.
@Model
final class ExerciseMapEntry {
    @Attribute(.unique) var exercise: String
    var primaryRaw: String
    var secondaryRaw: [String]
    var fromSource: Bool

    init(exercise: String, muscles: ExerciseMuscles, fromSource: Bool = false) {
        self.exercise = MuscleMap.normalize(exercise)
        self.primaryRaw = muscles.primary.rawValue
        self.secondaryRaw = muscles.secondary.map(\.rawValue)
        self.fromSource = fromSource
    }

    var muscles: ExerciseMuscles? {
        guard let p = Muscle(rawValue: primaryRaw) else { return nil }
        return ExerciseMuscles(primary: p, secondary: secondaryRaw.compactMap(Muscle.init(rawValue:)))
    }
}

// MARK: - ProgressPhoto

enum PhotoPose: String, Codable, CaseIterable, Identifiable {
    case front, side, back, custom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@Model
final class ProgressPhoto {
    @Attribute(.unique) var id: UUID
    var date: Date
    var poseRaw: String
    var customPoseName: String?
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var trendWeightLb: Double?
    var bodyFatPercent: Double?
    var phaseRaw: String?

    init(date: Date, pose: PhotoPose, customPoseName: String? = nil, imageData: Data, thumbnailData: Data?, trendWeightLb: Double?, bodyFatPercent: Double?, phase: Phase?) {
        self.id = UUID()
        self.date = date
        self.poseRaw = pose.rawValue
        self.customPoseName = customPoseName
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.trendWeightLb = trendWeightLb
        self.bodyFatPercent = bodyFatPercent
        self.phaseRaw = phase?.rawValue
    }

    var pose: PhotoPose { PhotoPose(rawValue: poseRaw) ?? .custom }
    var poseTitle: String { pose == .custom ? (customPoseName ?? "Custom") : pose.title }
    var phase: Phase? { phaseRaw.flatMap(Phase.init(rawValue:)) }
}

// MARK: - Recommendation

enum RecommendationStatus: String, Codable {
    case open, accepted, dismissed, snoozed
}

@Model
final class Recommendation {
    @Attribute(.unique) var id: UUID
    var date: Date
    var ruleRaw: String
    var payload: Data
    var statusRaw: String
    var snoozedUntil: Date?
    var resolvedAt: Date?
    var appliedKcalChange: Double?
    var headline: String

    init(recommendation: CoachRecommendation) {
        self.id = recommendation.id
        self.date = recommendation.date
        self.ruleRaw = recommendation.rule.rawValue
        self.payload = (try? Dials.jsonEncoder.encode(recommendation)) ?? Data()
        self.statusRaw = RecommendationStatus.open.rawValue
        self.headline = recommendation.headline
    }

    var rule: CoachRule { CoachRule(rawValue: ruleRaw) ?? .rateOffTarget }
    var status: RecommendationStatus {
        get { RecommendationStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var decoded: CoachRecommendation? {
        try? Dials.jsonDecoder.decode(CoachRecommendation.self, from: payload)
    }

    /// Open, or snoozed and the snooze has passed.
    func isActionable(on date: Date) -> Bool {
        switch status {
        case .open: return true
        case .snoozed: return (snoozedUntil ?? date) <= date
        default: return false
        }
    }
}

// MARK: - ImportMapping

@Model
final class ImportMappingRecord {
    @Attribute(.unique) var sourceName: String
    var mappingJSON: Data
    var weightUnit: String
    var lastUsed: Date

    init(sourceName: String, mappingJSON: Data, weightUnit: String) {
        self.sourceName = sourceName
        self.mappingJSON = mappingJSON
        self.weightUnit = weightUnit
        self.lastUsed = Date()
    }
}

// MARK: - Preset

@Model
final class PresetRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var created: Date
    var dialsJSON: Data

    init(name: String, dials: Dials) {
        self.id = UUID()
        self.name = name
        self.created = Date()
        self.dialsJSON = (try? dials.encodedJSON()) ?? Data()
    }

    var dials: Dials? { try? Dials.decode(json: dialsJSON) }
}

// MARK: - DialChange

enum DialChangeSource: String, Codable {
    case user, coach, preset, onboarding, undo
}

@Model
final class DialChange {
    @Attribute(.unique) var id: UUID
    var date: Date
    var key: String
    var title: String
    var oldValueJSON: Data
    var newValueJSON: Data
    var oldDescription: String
    var newDescription: String
    var sourceRaw: String
    var recommendationID: UUID?

    init(key: DialKey, title: String, oldValue: DialValue, newValue: DialValue, source: DialChangeSource, recommendationID: UUID? = nil, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.key = key.rawValue
        self.title = title
        self.oldValueJSON = (try? Dials.jsonEncoder.encode(oldValue)) ?? Data()
        self.newValueJSON = (try? Dials.jsonEncoder.encode(newValue)) ?? Data()
        self.oldDescription = oldValue.compactDescription
        self.newDescription = newValue.compactDescription
        self.sourceRaw = source.rawValue
        self.recommendationID = recommendationID
    }

    var dialKey: DialKey { DialKey(key) }
    var source: DialChangeSource { DialChangeSource(rawValue: sourceRaw) ?? .user }
    var oldValue: DialValue? { try? Dials.jsonDecoder.decode(DialValue.self, from: oldValueJSON) }
    var newValue: DialValue? { try? Dials.jsonDecoder.decode(DialValue.self, from: newValueJSON) }
}

// MARK: - Container

enum Persistence {
    static let schema = Schema([
        DayRecord.self, LiftSet.self, ExerciseMapEntry.self, ProgressPhoto.self,
        Recommendation.self, ImportMappingRecord.self, PresetRecord.self, DialChange.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration("Tare", schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A broken store on a dev build: start fresh rather than crash on launch forever.
            let fallback = ModelConfiguration("Tare-recovery", schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
