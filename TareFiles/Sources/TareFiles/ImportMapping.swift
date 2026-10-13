import Foundation

/// What a spreadsheet column feeds in Tare.
public enum ImportField: String, Codable, CaseIterable, Sendable {
    case date, weight, bodyFat, leanMass, calories, protein, carbs, fat, water, steps, activeEnergy
    case liftMinutes, liftStyle, cardioMinutes, cardioDetail, foodLogComplete, liftingOverride
    case exercise, setIndex, setType, setWeight, reps, rpe, workoutStart, workoutEnd, workoutTitle
    case ignore

    public var title: String {
        switch self {
        case .date: return "Date"
        case .weight: return "Body weight"
        case .bodyFat: return "Body fat %"
        case .leanMass: return "Lean mass"
        case .calories: return "Calories"
        case .protein: return "Protein (g)"
        case .carbs: return "Carbs (g)"
        case .fat: return "Fat (g)"
        case .water: return "Water (oz)"
        case .steps: return "Steps"
        case .activeEnergy: return "Active energy (kcal)"
        case .liftMinutes: return "Lift minutes"
        case .liftStyle: return "Lift style"
        case .cardioMinutes: return "Cardio minutes"
        case .cardioDetail: return "Cardio detail"
        case .foodLogComplete: return "Food log complete"
        case .liftingOverride: return "Lifting override"
        case .exercise: return "Exercise"
        case .setIndex: return "Set number"
        case .setType: return "Set type"
        case .setWeight: return "Set weight"
        case .reps: return "Reps"
        case .rpe: return "RPE"
        case .workoutStart: return "Workout start"
        case .workoutEnd: return "Workout end"
        case .workoutTitle: return "Workout title"
        case .ignore: return "Ignore"
        }
    }

    /// Fields that describe a day (the Days import).
    public static let dayFields: [ImportField] = [.date, .weight, .bodyFat, .leanMass, .calories, .protein, .carbs, .fat, .water, .steps, .activeEnergy, .liftMinutes, .liftStyle, .cardioMinutes, .cardioDetail, .foodLogComplete, .liftingOverride]

    /// Fields that describe a set (the Lifts import).
    public static let liftFields: [ImportField] = [.date, .exercise, .setIndex, .setType, .setWeight, .reps, .rpe, .workoutStart, .workoutEnd, .workoutTitle]
}

/// Column name → field. Columns absent from `fields` are ignored.
public struct ColumnMapping: Codable, Equatable, Sendable {
    public var fields: [String: ImportField]

    public init(fields: [String: ImportField] = [:]) {
        self.fields = fields
    }

    public subscript(column: String) -> ImportField? {
        get { fields[column] }
        set { fields[column] = newValue }
    }

    /// Column names mapped to the given field, in no particular order.
    public func columns(for field: ImportField) -> [String] {
        fields.filter { $0.value == field }.map(\.key)
    }

    public func contains(_ field: ImportField) -> Bool {
        fields.values.contains(field)
    }

    /// True when the mapping has what a lift-set import needs: an exercise and a date source.
    public var describesLifts: Bool {
        contains(.exercise) && (contains(.date) || contains(.workoutStart))
    }
}

public enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case lb, kg
}

/// Hints for parsing an import.
public struct ImportOptions: Codable, Equatable, Sendable {
    /// Unit of weight columns whose names don't say "kg" or "lb".
    public var weightUnit: WeightUnit
    /// Extra `DateFormatter` patterns tried before the built-in ones.
    public var dateFormats: [String]

    public init(weightUnit: WeightUnit = .lb, dateFormats: [String] = []) {
        self.weightUnit = weightUnit
        self.dateFormats = dateFormats
    }

    public static let `default` = ImportOptions()
}

/// Guesses which field each column feeds, from its name alone.
public enum MappingGuesser {

    /// Keyword-based guess, case-insensitive. When an exercise column is present, a bare
    /// "weight" column means the set weight rather than body weight.
    public static func guess(columns: [String]) -> ColumnMapping {
        let hasExercise = columns.contains { isExerciseColumn(normalize($0)) }
        var fields: [String: ImportField] = [:]
        var taken: Set<ImportField> = []
        for column in columns {
            let guess = guessField(column, hasExercise: hasExercise)
            // One column per field: keep the first match, except `ignore`.
            if guess != .ignore, taken.contains(guess) {
                fields[column] = .ignore
            } else {
                fields[column] = guess
                taken.insert(guess)
            }
        }
        return ColumnMapping(fields: fields)
    }

    /// Lowercases, replaces punctuation with spaces and collapses whitespace.
    static func normalize(_ name: String) -> String {
        var out = ""
        var lastSpace = true
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber || ch == "%" || ch == "#" {
                out.append(ch)
                lastSpace = false
            } else if !lastSpace {
                out.append(" ")
                lastSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func isExerciseColumn(_ n: String) -> Bool {
        n == "exercise" || n == "exercise title" || n == "exercise name" || n == "movement" || n == "lift" || n == "lift name" || n == "exercise_title"
    }

    static func words(_ n: String) -> Set<String> { Set(n.split(separator: " ").map(String.init)) }

    static func guessField(_ column: String, hasExercise: Bool) -> ImportField {
        let n = normalize(column)
        let w = words(n)
        guard !n.isEmpty else { return .ignore }

        // Timestamps and titles
        if n == "start time" || n == "start" || n == "started" || n == "workout start" || n == "start date" { return .workoutStart }
        if n == "end time" || n == "end" || n == "finished" || n == "workout end" || n == "end date" { return .workoutEnd }
        if n == "title" || n == "workout name" || n == "workout" || n == "routine" || n == "workout title" || n == "routine name" { return .workoutTitle }

        // Noise columns from Hevy and Strong
        if n == "description" || n == "superset id" || n == "exercise notes" || n == "notes" || n == "workout notes" || n == "note"
            || n.hasPrefix("distance") || n == "duration seconds" || n == "seconds" || n == "duration" || n == "rest timer" { return .ignore }

        // Dates
        if n == "date" || n == "day" || n == "date logged" || n == "log date" || n == "entry date" || w.contains("date") && !w.contains("birth") { return .date }
        if n == "time" || n == "timestamp" || n == "datetime" || n == "created at" || n == "logged at" { return .date }

        // Lifting
        if isExerciseColumn(n) { return .exercise }
        if n == "set index" || n == "set order" || n == "set #" || n == "set number" || n == "set" || n == "set no" || n == "setindex" { return .setIndex }
        if n == "set type" || n == "settype" || (hasExercise && n == "type") { return .setType }
        if w.contains("rpe") { return .rpe }
        if w.contains("reps") || w.contains("rep") || n == "repetitions" { return .reps }

        // Body composition (before generic weight / fat)
        if n.contains("body fat") || n.contains("bodyfat") || n.contains("fat %") || n.contains("fat%") || n == "bf" || n == "bf%" || n.hasPrefix("bf ") || n.contains("fat percent") || n.contains("fat pct") || n == "body fat pct" { return .bodyFat }
        if n.contains("lean") || n.contains("ffm") || n.contains("fat free") || n.contains("muscle mass") { return .leanMass }

        // Weight: set weight when an exercise column exists and the column isn't about the body
        if w.contains("weight") || w.contains("bodyweight") || n == "bw" || n.contains("scale") || n.contains("load") && hasExercise {
            let aboutBody = n.contains("body") || n == "bw" || n.contains("scale")
            if hasExercise && !aboutBody { return .setWeight }
            return .weight
        }

        // Energy
        if n.contains("active energy") || n.contains("active calories") || n.contains("active kcal") || n.contains("exercise energy") || n.contains("exercise calories") || n.contains("burned") || n.contains("expenditure") && !n.contains("total") { return .activeEnergy }
        if w.contains("kcal") || n.contains("calorie") || w.contains("energy") || n == "cal" || n == "cals" || n == "intake" { return .calories }

        // Macros
        if n.contains("protein") || n == "p" || n == "prot" || n == "protein g" { return .protein }
        if n.contains("carb") || n == "cho" || n == "c" { return .carbs }
        if w.contains("fat") || n == "f" || n == "fats" || n == "fat g" { return .fat }
        if n.contains("water") || n.contains("h2o") || n.contains("fluid") { return .water }
        if w.contains("steps") || w.contains("step") { return .steps }

        // Training time
        if n.contains("lift style") || n.contains("training style") || n == "style" || n == "lift type" { return .liftStyle }
        if (n.contains("lift") || n.contains("strength") || n.contains("resistance")) && (n.contains("min") || n.contains("duration") || n.contains("time")) || n == "lifting" || n == "lift minutes" { return .liftMinutes }
        if n.contains("cardio") && (n.contains("detail") || n.contains("session") || n.contains("type")) { return .cardioDetail }
        if n.contains("cardio") { return .cardioMinutes }
        if n.contains("food log") || n.contains("log complete") || n == "complete" || n == "completed" || n == "logged" || n == "food log complete" { return .foodLogComplete }
        if n.contains("lifting override") || n.contains("lifting today") || n == "lifting" { return .liftingOverride }

        return .ignore
    }

    /// Recognizes well-known export headers: "Hevy", "Strong", "MacroFactor", "Cronometer",
    /// "MyFitnessPal", "Tare", or nil.
    public static func detectSource(columns: [String]) -> String? {
        let set = Set(columns.map { normalize($0) })
        func has(_ names: String...) -> Bool { names.allSatisfy { set.contains($0) } }

        if has("exercise title", "set index") || has("exercise title", "start time") { return "Hevy" }
        if has("workout name", "exercise name", "set order") || has("exercise name", "set order") { return "Strong" }
        if has("date", "body fat pct", "lift minutes") || has("date", "weight lb", "food log complete")
            || has("date", "exercise", "set index", "set type", "weight lb") { return "Tare" }
        if set.contains("expenditure") || set.contains("expenditure kcal")
            || (has("date", "calories") && (set.contains("weight lb") || set.contains("weight kg")) && set.contains("protein g")) { return "MacroFactor" }
        if has("day", "energy kcal") || set.contains("energy kcal") && set.contains("completed") { return "Cronometer" }
        if has("date", "meal", "calories") || set.contains("sodium mg") && set.contains("calories") { return "MyFitnessPal" }
        return nil
    }
}
