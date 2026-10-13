import Foundation

public enum Muscle: String, Codable, CaseIterable, Sendable, Comparable {
    case chest, back, shoulders, biceps, triceps, forearms, abs, quads, hamstrings, glutes, calves

    public var title: String {
        switch self {
        case .abs: return "Abs"
        default: return rawValue.capitalized
        }
    }

    public static func < (lhs: Muscle, rhs: Muscle) -> Bool {
        (Muscle.allCases.firstIndex(of: lhs) ?? 0) < (Muscle.allCases.firstIndex(of: rhs) ?? 0)
    }

    /// Where the muscle sits on the body-map silhouettes.
    public var isFront: Bool {
        switch self {
        case .chest, .shoulders, .biceps, .forearms, .abs, .quads: return true
        case .back, .triceps, .hamstrings, .glutes, .calves: return false
        }
    }
}

public struct ExerciseMuscles: Codable, Equatable, Sendable {
    public var primary: Muscle
    public var secondary: [Muscle]

    public init(primary: Muscle, secondary: [Muscle] = []) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// Exercise name → muscles. Built-in keyword rules plus the user's own tags, and whatever
/// the source (Hevy) says when it provides muscle groups.
public struct MuscleMap: Equatable, Sendable {
    /// Exact matches on the normalised name. User tags and source-provided groups go here.
    public var overrides: [String: ExerciseMuscles]

    public init(overrides: [String: ExerciseMuscles] = [:]) {
        self.overrides = overrides
    }

    public static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").joined(separator: " ")
    }

    public mutating func tag(_ exercise: String, as muscles: ExerciseMuscles) {
        overrides[MuscleMap.normalize(exercise)] = muscles
    }

    public func lookup(_ exercise: String) -> ExerciseMuscles? {
        let key = MuscleMap.normalize(exercise)
        if let o = overrides[key] { return o }
        return MuscleMap.builtIn(key)
    }

    /// Exercises the map can't place, for the "tag once" prompt.
    public func unknownExercises(in sets: [LiftSetInput]) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for s in sets {
            let key = MuscleMap.normalize(s.exercise)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if lookup(s.exercise) == nil { out.append(s.exercise) }
        }
        return out
    }

    /// Keyword rules, most specific first.
    static func builtIn(_ name: String) -> ExerciseMuscles? {
        let rules: [(keywords: [String], muscles: ExerciseMuscles)] = [
            (["leg curl", "lying curl", "seated curl", "nordic"], ExerciseMuscles(primary: .hamstrings, secondary: [.glutes])),
            (["romanian", "rdl", "stiff leg", "good morning"], ExerciseMuscles(primary: .hamstrings, secondary: [.glutes, .back])),
            (["hip thrust", "glute bridge", "kickback", "hip abduction"], ExerciseMuscles(primary: .glutes, secondary: [.hamstrings])),
            (["sumo deadlift"], ExerciseMuscles(primary: .glutes, secondary: [.quads, .hamstrings, .back])),
            (["deadlift"], ExerciseMuscles(primary: .back, secondary: [.hamstrings, .glutes])),
            (["front squat", "hack squat", "leg press", "leg extension", "sissy"], ExerciseMuscles(primary: .quads, secondary: [.glutes])),
            (["bulgarian", "split squat", "lunge", "step up"], ExerciseMuscles(primary: .quads, secondary: [.glutes, .hamstrings])),
            (["squat"], ExerciseMuscles(primary: .quads, secondary: [.glutes, .hamstrings])),
            (["calf", "calves"], ExerciseMuscles(primary: .calves)),
            (["incline", "decline", "bench", "chest press", "push up", "pushup", "fly", "flye", "pec deck", "crossover"], ExerciseMuscles(primary: .chest, secondary: [.triceps, .shoulders])),
            (["dip"], ExerciseMuscles(primary: .chest, secondary: [.triceps])),
            (["face pull", "rear delt", "reverse fly", "reverse pec"], ExerciseMuscles(primary: .shoulders, secondary: [.back])),
            (["lateral raise", "side raise", "front raise", "upright row"], ExerciseMuscles(primary: .shoulders)),
            (["overhead press", "shoulder press", "military", "ohp", "arnold", "push press"], ExerciseMuscles(primary: .shoulders, secondary: [.triceps])),
            (["shrug"], ExerciseMuscles(primary: .back)),
            (["pull up", "pullup", "chin up", "chinup", "pulldown", "pull down"], ExerciseMuscles(primary: .back, secondary: [.biceps])),
            (["row", "pullover"], ExerciseMuscles(primary: .back, secondary: [.biceps])),
            (["hammer curl", "reverse curl", "wrist", "forearm"], ExerciseMuscles(primary: .forearms, secondary: [.biceps])),
            (["curl"], ExerciseMuscles(primary: .biceps, secondary: [.forearms])),
            (["tricep", "pushdown", "push down", "skull", "overhead extension", "kickback", "close grip", "jm press"], ExerciseMuscles(primary: .triceps)),
            (["crunch", "plank", "sit up", "situp", "leg raise", "ab ", "abs", "cable twist", "rollout"], ExerciseMuscles(primary: .abs)),
        ]
        let padded = " " + name + " "
        for rule in rules {
            for k in rule.keywords where padded.contains(k) {
                return rule.muscles
            }
        }
        return nil
    }
}

public struct WeekSets: Equatable, Identifiable, Sendable {
    public var id: Date { weekStart }
    public let weekStart: Date
    public let weekEnd: Date
    public let sets: [Muscle: Double]
}

public struct SessionE1RM: Equatable, Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let e1RM: Double
    public let bestSetWeightLb: Double
    public let bestSetReps: Int
}

public struct ExerciseStrength: Equatable, Identifiable, Sendable {
    public var id: String { exercise }
    public let exercise: String
    public let sessions: [SessionE1RM]
    public var latest: Double? { sessions.last?.e1RM }
    public var sessionCount: Int { sessions.count }

    /// Change in e1RM between the first session at or after `since` and the latest.
    public func change(since: Date) -> Double? {
        guard let last = sessions.last, let first = sessions.first(where: { $0.date >= since }) ?? sessions.first else { return nil }
        guard first.date < last.date else { return nil }
        return last.e1RM - first.e1RM
    }

    public func percentChange(since: Date) -> Double? {
        guard let last = sessions.last, let first = sessions.first(where: { $0.date >= since }) ?? sessions.first, first.e1RM > 0, first.date < last.date else { return nil }
        return (last.e1RM - first.e1RM) / first.e1RM * 100
    }
}

public enum LiftAnalytics {

    /// Epley: weight × (1 + reps ÷ 30).
    public static func epley(weightLb: Double, reps: Int) -> Double {
        weightLb * (1 + Double(reps) / 30)
    }

    /// Hard sets per muscle per week, for the `weeks` seven-day blocks ending today. Oldest first.
    /// Each working set credits 1 to the primary muscle and 0.5 to each secondary.
    public static func weeklyHardSets(sets: [LiftSetInput], map: MuscleMap, weeks: Int, today: Date, calendar: Calendar = .current) -> [WeekSets] {
        guard weeks > 0 else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        var buckets: [[Muscle: Double]] = Array(repeating: [:], count: weeks)
        for s in sets where s.setType.isWorking {
            let back = calendar.days(from: s.date, to: today)
            guard back >= 0 else { continue }
            let week = back / 7
            guard week < weeks else { continue }
            guard let m = map.lookup(s.exercise) else { continue }
            buckets[week][m.primary, default: 0] += 1
            for sec in m.secondary {
                buckets[week][sec, default: 0] += 0.5
            }
        }
        return (0..<weeks).reversed().compactMap { week in
            guard let end = calendar.date(byAdding: .day, value: -(week * 7), to: todayStart),
                  let start = calendar.date(byAdding: .day, value: -6, to: end) else { return nil }
            return WeekSets(weekStart: start, weekEnd: end, sets: buckets[week])
        }
    }

    public static func averageWeeklySets(_ weeks: [WeekSets]) -> [Muscle: Double] {
        guard !weeks.isEmpty else { return [:] }
        var totals: [Muscle: Double] = [:]
        for w in weeks {
            for (m, v) in w.sets { totals[m, default: 0] += v }
        }
        return totals.mapValues { $0 / Double(weeks.count) }
    }

    /// Per-session estimated 1RM from the best working set of 10 reps or fewer.
    public static func strength(sets: [LiftSetInput], calendar: Calendar = .current) -> [ExerciseStrength] {
        var byExercise: [String: [Date: SessionE1RM]] = [:]
        for s in sets where s.setType.isWorking && s.reps > 0 && s.reps <= 10 && s.weightLb > 0 {
            let day = calendar.startOfDay(for: s.date)
            let e = epley(weightLb: s.weightLb, reps: s.reps)
            let existing = byExercise[s.exercise]?[day]
            if existing == nil || e > existing!.e1RM {
                byExercise[s.exercise, default: [:]][day] = SessionE1RM(date: day, e1RM: e, bestSetWeightLb: s.weightLb, bestSetReps: s.reps)
            }
        }
        return byExercise.map { exercise, sessions in
            ExerciseStrength(exercise: exercise, sessions: sessions.values.sorted { $0.date < $1.date })
        }.sorted { $0.sessionCount == $1.sessionCount ? $0.exercise < $1.exercise : $0.sessionCount > $1.sessionCount }
    }

    /// e1RM ÷ trend weight: whether a cut is costing strength.
    public static func relativeStrength(e1RM: Double, trendWeightLb: Double) -> Double? {
        guard trendWeightLb > 0 else { return nil }
        return e1RM / trendWeightLb
    }

    /// Muscles with sessions in at least `dials.muscleUnlockWeeks` distinct weeks.
    public static func unlockedMuscles(sets: [LiftSetInput], map: MuscleMap, dials: Dials, today: Date, calendar: Calendar = .current) -> Set<Muscle> {
        var weeksByMuscle: [Muscle: Set<Int>] = [:]
        for s in sets where s.setType.isWorking {
            let back = calendar.days(from: s.date, to: today)
            guard back >= 0, let m = map.lookup(s.exercise) else { continue }
            weeksByMuscle[m.primary, default: []].insert(back / 7)
            for sec in m.secondary { weeksByMuscle[sec, default: []].insert(back / 7) }
        }
        return Set(weeksByMuscle.filter { $0.value.count >= dials.muscleUnlockWeeks }.keys)
    }

    /// Exercises with at least `dials.exerciseUnlockSessions` sessions.
    public static func unlockedExercises(_ strength: [ExerciseStrength], dials: Dials) -> [ExerciseStrength] {
        strength.filter { $0.sessionCount >= dials.exerciseUnlockSessions }
    }

    /// Percent change of e1RM over `weeks`, averaged across exercises whose primary muscle matches, for the body map.
    public static func strengthChangeByMuscle(strength: [ExerciseStrength], map: MuscleMap, weeks: Int, today: Date, calendar: Calendar = .current) -> [Muscle: Double] {
        guard let since = calendar.date(byAdding: .day, value: -weeks * 7, to: calendar.startOfDay(for: today)) else { return [:] }
        var sums: [Muscle: (total: Double, count: Int)] = [:]
        for ex in strength {
            guard let m = map.lookup(ex.exercise), let pct = ex.percentChange(since: since) else { continue }
            let cur = sums[m.primary] ?? (0, 0)
            sums[m.primary] = (cur.total + pct, cur.count + 1)
        }
        return sums.mapValues { $0.total / Double($0.count) }
    }

    /// Exercises in the log that train a muscle, most-used first.
    public static func exercises(for muscle: Muscle, in sets: [LiftSetInput], map: MuscleMap) -> [String] {
        var counts: [String: Int] = [:]
        for s in sets {
            guard let m = map.lookup(s.exercise), m.primary == muscle || m.secondary.contains(muscle) else { continue }
            counts[s.exercise, default: 0] += 1
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
    }
}
