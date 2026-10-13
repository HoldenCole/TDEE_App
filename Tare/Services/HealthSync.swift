import Foundation
import HealthKit
import TareEngine

/// Reads Health into `DayInput`s. Read-only: the app never writes to Health.
@MainActor
final class HealthSync {
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    // MARK: Types

    private var quantityTypes: [HKQuantityTypeIdentifier: HKQuantityType] {
        var out: [HKQuantityTypeIdentifier: HKQuantityType] = [:]
        for id in [HKQuantityTypeIdentifier.bodyMass, .bodyFatPercentage, .leanBodyMass, .height, .stepCount, .activeEnergyBurned, .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .dietaryWater] {
            if let t = HKObjectType.quantityType(forIdentifier: id) { out[id] = t }
        }
        return out
    }

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>(quantityTypes.values.map { $0 as HKObjectType })
        set.insert(HKObjectType.workoutType())
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { set.insert(dob) }
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { set.insert(sex) }
        return set
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        guard HealthSync.isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        AppState.healthAuthorized = true
    }

    // MARK: Profile

    struct Profile {
        var sex: Sex?
        var birthDate: Date?
        var heightCm: Double?
    }

    func profile() async -> Profile {
        var p = Profile()
        if let comps = try? store.dateOfBirthComponents(), let date = Calendar.current.date(from: comps) {
            p.birthDate = date
        }
        if let sexObject = try? store.biologicalSex() {
            switch sexObject.biologicalSex {
            case .male: p.sex = .male
            case .female: p.sex = .female
            default: p.sex = nil
            }
        }
        if let heightType = quantityTypes[.height] {
            let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: heightType)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
            if let sample = try? await descriptor.result(for: store).first {
                p.heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            }
        }
        return p
    }

    // MARK: Fetch

    /// Pulls every day between the two dates, one `DayInput` per day that has any data.
    func fetchDays(from start: Date, to end: Date) async throws -> [DayInput] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        var days: [Date: DayInput] = [:]

        func day(_ date: Date) -> DayInput {
            let key = calendar.startOfDay(for: date)
            return days[key] ?? DayInput(date: key)
        }
        func update(_ date: Date, _ body: (inout DayInput) -> Void) {
            let key = calendar.startOfDay(for: date)
            var d = day(key)
            body(&d)
            days[key] = d
        }

        // Daily sums
        let sums: [(HKQuantityTypeIdentifier, HKUnit, (inout DayInput, Double) -> Void)] = [
            (.stepCount, .count(), { $0.steps = Int($1.rounded()) }),
            (.activeEnergyBurned, .kilocalorie(), { $0.activeEnergyKcal = $1 }),
            (.dietaryEnergyConsumed, .kilocalorie(), { $0.calories = $1 }),
            (.dietaryProtein, .gram(), { $0.proteinG = $1 }),
            (.dietaryCarbohydrates, .gram(), { $0.carbsG = $1 }),
            (.dietaryFatTotal, .gram(), { $0.fatG = $1 }),
            (.dietaryWater, .fluidOunceUS(), { $0.waterOz = $1 }),
        ]
        for (id, unit, apply) in sums {
            guard let type = quantityTypes[id] else { continue }
            let totals = try await dailySums(type: type, unit: unit, from: startDay, to: endDay)
            for (date, value) in totals where value > 0 {
                update(date) { apply(&$0, value) }
            }
        }

        // Latest sample per day for body measurements
        if let t = quantityTypes[.bodyMass] {
            for (date, v) in try await latestPerDay(type: t, unit: .pound(), from: startDay, to: endDay) {
                update(date) { $0.weightLb = v }
            }
        }
        if let t = quantityTypes[.bodyFatPercentage] {
            for (date, v) in try await latestPerDay(type: t, unit: .percent(), from: startDay, to: endDay) {
                update(date) { $0.bodyFatPercent = v * 100 }
            }
        }
        if let t = quantityTypes[.leanBodyMass] {
            for (date, v) in try await latestPerDay(type: t, unit: .pound(), from: startDay, to: endDay) {
                update(date) { $0.leanMassLb = v }
            }
        }

        // Workouts
        for w in try await workouts(from: startDay, to: endDay) {
            let minutes = w.duration / 60
            guard minutes > 0 else { continue }
            if HealthSync.isStrength(w.workoutActivityType) {
                update(w.startDate) { d in
                    d.liftMinutes = (d.liftMinutes ?? 0) + minutes
                }
            } else {
                let name = HealthSync.cardioName(w.workoutActivityType)
                update(w.startDate) { d in
                    if let i = d.cardioSessions.firstIndex(where: { $0.type == name }) {
                        d.cardioSessions[i].minutes += minutes
                    } else {
                        d.cardioSessions.append(CardioSession(type: name, minutes: minutes))
                    }
                }
            }
        }

        return days.values.sorted { $0.date < $1.date }
    }

    private func dailySums(type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var out: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: endExclusive) { stats, _ in
            if let q = stats.sumQuantity() {
                out[calendar.startOfDay(for: stats.startDate)] = q.doubleValue(for: unit)
            }
        }
        return out
    }

    private func latestPerDay(type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate)])
        let samples = try await descriptor.result(for: store)
        var out: [Date: Double] = [:]
        for s in samples {
            // Sorted ascending, so the last write for a day wins: the latest sample.
            out[calendar.startOfDay(for: s.endDate)] = s.quantity.doubleValue(for: unit)
        }
        return out
    }

    private func workouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: store)
    }

    static func isStrength(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return true
        default: return false
        }
    }

    /// Maps a Health workout type onto the cardio names in `Dials.cardioTypes`.
    static func cardioName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking, .hiking: return "Walk"
        case .running: return "Run"
        case .cycling, .handCycling: return "Bike"
        case .stairClimbing, .stairs, .stepTraining: return "Stairs"
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio: return "HIIT"
        case .swimming: return "Swim"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        default: return "Other"
        }
    }

    // MARK: Background delivery

    /// Asks Health to wake the app when new weigh-ins, food, steps or workouts arrive.
    func startBackgroundDelivery(onChange: @escaping () -> Void) {
        guard observerQueries.isEmpty else { return }
        var types: [HKSampleType] = quantityTypes.values.map { $0 as HKSampleType }
        types.append(HKObjectType.workoutType())
        for type in types {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                DispatchQueue.main.async { onChange() }
                completion()
            }
            store.execute(query)
            observerQueries.append(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }

    func stopBackgroundDelivery() {
        for q in observerQueries { store.stop(q) }
        observerQueries.removeAll()
    }
}
