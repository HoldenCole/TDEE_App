import Foundation
import TareEngine
import TareFiles

/// Pulls workouts from the Hevy API into LiftSets and tags exercises with Hevy's muscle groups.
@MainActor
enum HevyConnector {
    struct Outcome {
        var setsAdded: Int
        var workouts: Int
        var tagged: Int
    }

    static var hasKey: Bool { !(Keychain.get(Keychain.hevyKey) ?? "").isEmpty }

    static func sync(model: AppModel, fullHistory: Bool = false) async throws -> Outcome {
        guard let key = Keychain.get(Keychain.hevyKey), !key.isEmpty else { throw HevyError.invalidAPIKey }
        let client = HevyClient(apiKey: key)
        var since: Date? = nil
        if !fullHistory, let last = AppState.hevyLastSync {
            since = Calendar.current.date(byAdding: .day, value: -7, to: last)
        }
        let known = Set(model.liftSets.map { MuscleMap.normalize($0.exercise) })
        let result = try await client.fetchWorkouts(since: since, pageSize: 10, knownExercises: known)
        let added = model.addLiftSets(result.sets, batchID: "hevy")

        // Fill lift minutes on days Health didn't cover.
        var dayUpdates: [DayInput] = []
        for w in result.workouts {
            guard let minutes = w.durationMinutes, minutes > 0 else { continue }
            if let existing = model.dayRecord(for: w.start, create: false), existing.liftMinutes != nil { continue }
            dayUpdates.append(DayInput(date: Calendar.current.startOfDay(for: w.start), liftMinutes: minutes))
        }
        if !dayUpdates.isEmpty { model.upsertDays(dayUpdates, synced: true) }

        // Use Hevy's muscle groups for exercises the built-in map doesn't know.
        var tagged = 0
        for exercise in model.untaggedExercises {
            guard let templateID = result.templateIDs[exercise] else { continue }
            if let template = try? await client.exerciseTemplate(id: templateID), let primary = template.primaryMuscle {
                model.tagExercise(exercise, as: ExerciseMuscles(primary: primary, secondary: template.secondaryMuscles), fromSource: true)
                tagged += 1
            }
        }
        AppState.hevyLastSync = Date()
        return Outcome(setsAdded: added, workouts: result.workouts.count, tagged: tagged)
    }
}
