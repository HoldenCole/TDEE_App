import Foundation
import TareEngine

/// What an import produced, plus what it could not use.
public struct ImportResult<T: Sendable>: Sendable {
    public var items: [T]
    public var skippedRows: Int
    public var problems: [String]

    public init(items: [T] = [], skippedRows: Int = 0, problems: [String] = []) {
        self.items = items
        self.skippedRows = skippedRows
        self.problems = problems
    }
}

/// Turns a mapped table into engine inputs.
public enum ImportParser {

    static let maxProblems = 50

    /// A resolved row: field → (column name, raw value). Later columns for the same field win
    /// only when they are non-empty.
    struct Row {
        var values: [ImportField: (column: String, value: String)] = [:]

        subscript(field: ImportField) -> String? {
            guard let v = values[field]?.value else { return nil }
            let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func column(_ field: ImportField) -> String? { values[field]?.column }
    }

    static func resolve(_ table: Table, mapping: ColumnMapping) -> [Row] {
        // Column index → field, matching mapping keys exactly first, then loosely.
        var fieldForColumn: [Int: ImportField] = [:]
        for (name, field) in mapping.fields where field != .ignore {
            if let i = table.columnIndex(name) { fieldForColumn[i] = field }
        }
        return table.rows.map { cells in
            var row = Row()
            for (i, field) in fieldForColumn.sorted(by: { $0.key < $1.key }) {
                guard i < cells.count else { continue }
                let value = cells[i]
                let column = table.columns[i]
                if row.values[field] == nil || !value.trimmingCharacters(in: .whitespaces).isEmpty {
                    row.values[field] = (column, value)
                }
            }
            return row
        }
    }

    static func rowDate(_ row: Row, options: ImportOptions) -> Date? {
        if let s = row[.date], let d = DateParsing.date(s, extraFormats: options.dateFormats) { return d }
        if let s = row[.workoutStart], let d = DateParsing.date(s, extraFormats: options.dateFormats) { return d }
        return nil
    }

    /// Pounds from a weight cell, honoring a unit in the column name ("kg", "lb") and
    /// otherwise the options' unit. Units in the value itself ("80 kg") also count.
    static func pounds(_ raw: String, column: String?, options: ImportOptions) -> Double? {
        guard let n = NumberParsing.double(raw) else { return nil }
        let valueLower = raw.lowercased()
        let columnLower = (column ?? "").lowercased()
        let saysKg = valueLower.contains("kg") || valueLower.contains("kilo")
        let saysLb = valueLower.contains("lb") || valueLower.contains("pound")
        if saysKg { return Units.lb(fromKg: n) }
        if saysLb { return n }
        if columnLower.contains("kg") || columnLower.contains("kilo") { return Units.lb(fromKg: n) }
        if columnLower.contains("lb") || columnLower.contains("pound") { return n }
        return options.weightUnit == .kg ? Units.lb(fromKg: n) : n
    }

    // MARK: - Days

    /// One `DayInput` per calendar day. Rows with the same date merge; later rows override
    /// the fields they fill in. Rows without a parseable date are skipped.
    public static func days(from table: Table, mapping: ColumnMapping, options: ImportOptions = .default) -> ImportResult<DayInput> {
        var result = ImportResult<DayInput>()
        let calendar = Calendar.current
        var byDay: [Date: DayInput] = [:]
        var order: [Date] = []

        for (index, row) in resolve(table, mapping: mapping).enumerated() {
            let line = index + 2
            guard let date = rowDate(row, options: options) else {
                result.skippedRows += 1
                if row.values.contains(where: { !$0.value.value.isEmpty }) {
                    problem(&result, "Row \(line): no usable date (\(row[.date] ?? row[.workoutStart] ?? "blank")).")
                }
                continue
            }
            let day = calendar.startOfDay(for: date)
            var input = byDay[day] ?? DayInput(date: day)
            if byDay[day] == nil { order.append(day) }

            if let s = row[.weight] {
                if let lb = pounds(s, column: row.column(.weight), options: options) { input.weightLb = lb }
                else { problem(&result, "Row \(line): weight '\(s)' is not a number.") }
            }
            if let s = row[.bodyFat] {
                if let v = NumberParsing.double(s) { input.bodyFatPercent = v <= 1 && v > 0 ? v * 100 : v }
                else { problem(&result, "Row \(line): body fat '\(s)' is not a number.") }
            }
            if let s = row[.leanMass] {
                if let lb = pounds(s, column: row.column(.leanMass), options: options) { input.leanMassLb = lb }
            }
            if let s = row[.calories], let v = NumberParsing.double(s) { input.calories = v }
            if let s = row[.protein], let v = NumberParsing.double(s) { input.proteinG = v }
            if let s = row[.carbs], let v = NumberParsing.double(s) { input.carbsG = v }
            if let s = row[.fat], let v = NumberParsing.double(s) { input.fatG = v }
            if let s = row[.water], let v = NumberParsing.double(s) { input.waterOz = v }
            if let s = row[.steps], let v = NumberParsing.int(s) { input.steps = v }
            if let s = row[.activeEnergy], let v = NumberParsing.double(s) { input.activeEnergyKcal = v }
            if let s = row[.liftMinutes], let v = NumberParsing.double(s) { input.liftMinutes = v }
            if let s = row[.liftStyle] { input.liftStyle = s }
            if let s = row[.cardioDetail] {
                let sessions = parseCardioDetail(s)
                if !sessions.isEmpty { input.cardioSessions = sessions }
            } else if let s = row[.cardioMinutes], let v = NumberParsing.double(s) {
                if v > 0 { input.cardioSessions = [CardioSession(type: "Cardio", minutes: v)] }
                else { input.cardioSessions = [] }
            }
            if let s = row[.foodLogComplete], let b = NumberParsing.bool(s) { input.foodLogComplete = b }
            if let s = row[.liftingOverride], let b = NumberParsing.bool(s) { input.liftingOverride = b }

            byDay[day] = input
        }

        result.items = order.sorted().compactMap { byDay[$0] }
        finish(&result)
        return result
    }

    /// "Run:30; Bike:20" → sessions. Also accepts "Run 30, Bike 20" and "30 Run".
    public static func parseCardioDetail(_ s: String) -> [CardioSession] {
        var out: [CardioSession] = []
        for piece in s.split(whereSeparator: { $0 == ";" || $0 == "," || $0 == "|" }) {
            let p = piece.trimmingCharacters(in: .whitespaces)
            guard !p.isEmpty else { continue }
            if let colon = p.firstIndex(where: { $0 == ":" || $0 == "=" }) {
                let type = p[..<colon].trimmingCharacters(in: .whitespaces)
                let minutes = NumberParsing.double(String(p[p.index(after: colon)...])) ?? 0
                if !type.isEmpty, minutes > 0 { out.append(CardioSession(type: type, minutes: minutes)) }
                continue
            }
            let words = p.split(separator: " ").map(String.init)
            guard words.count >= 2 else { continue }
            if let m = NumberParsing.double(words.last!), m > 0 {
                let type = words.dropLast().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !type.isEmpty { out.append(CardioSession(type: type, minutes: m)) }
            } else if let m = NumberParsing.double(words.first!), m > 0 {
                let type = words.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !type.isEmpty { out.append(CardioSession(type: type, minutes: m)) }
            }
        }
        return out
    }

    /// Serializes cardio sessions as "Run:30;Bike:20".
    public static func cardioDetail(_ sessions: [CardioSession]) -> String {
        sessions.map { "\($0.type):\(ExportBuilder.number($0.minutes))" }.joined(separator: ";")
    }

    // MARK: - Lift sets

    /// Maps "warmup"/"warm-up"/"w" → warmup, "dropset"/"drop"/"d" → drop, "failure"/"f" → failure,
    /// anything else (including "normal", "working" and blank) → working.
    public static func setType(_ raw: String?) -> SetType {
        guard let raw else { return .working }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "")
        switch s {
        case "warmup", "warmupset", "w", "wu": return .warmup
        case "dropset", "drop", "d", "ds": return .drop
        case "failure", "fail", "f", "tofailure", "amrap": return .failure
        default: return .working
        }
    }

    /// One `LiftSetInput` per row. Rows without an exercise, date or reps are skipped, as are
    /// Strong's "Rest Timer" and "Note" rows. Weight is converted to pounds when the column name
    /// says kg or the options say kg. `setIndex` falls back to the running index within an
    /// exercise on a date. `source` defaults to the detected source name.
    public static func liftSets(from table: Table, mapping: ColumnMapping, options: ImportOptions = .default, source: String? = nil) -> ImportResult<LiftSetInput> {
        var result = ImportResult<LiftSetInput>()
        let sourceName = source ?? MappingGuesser.detectSource(columns: table.columns) ?? "Import"
        let calendar = Calendar.current
        var running: [String: Int] = [:] // "day|exercise" → next running index

        for (index, row) in resolve(table, mapping: mapping).enumerated() {
            let line = index + 2
            guard let exercise = row[.exercise] else {
                result.skippedRows += 1
                continue
            }
            if let order = row[.setIndex], NumberParsing.int(order) == nil {
                // Strong writes "Rest Timer" and "Note" rows into Set Order.
                result.skippedRows += 1
                continue
            }
            guard let date = rowDate(row, options: options) else {
                result.skippedRows += 1
                problem(&result, "Row \(line): no usable date (\(row[.date] ?? row[.workoutStart] ?? "blank")).")
                continue
            }
            guard let repsRaw = row[.reps], let reps = NumberParsing.int(repsRaw) else {
                result.skippedRows += 1
                continue
            }
            let weightRaw = row[.setWeight] ?? row[.weight]
            let weightColumn = row.column(.setWeight) ?? row.column(.weight)
            var weightLb = 0.0
            if let weightRaw {
                if let lb = pounds(weightRaw, column: weightColumn, options: options) { weightLb = lb }
                else { problem(&result, "Row \(line): weight '\(weightRaw)' is not a number; using 0.") }
            }
            let key = "\(calendar.startOfDay(for: date).timeIntervalSince1970)|\(exercise.lowercased())"
            let runningIndex = running[key, default: 0]
            running[key] = runningIndex + 1
            let setIndex = row[.setIndex].flatMap(NumberParsing.int) ?? runningIndex
            let rpe = row[.rpe].flatMap(NumberParsing.double)

            result.items.append(LiftSetInput(date: date, exercise: exercise, setIndex: setIndex, setType: setType(row[.setType]), weightLb: weightLb, reps: reps, rpe: rpe, source: sourceName))
        }
        finish(&result)
        return result
    }

    // MARK: - Problems

    static func problem<T>(_ result: inout ImportResult<T>, _ message: String) {
        if result.problems.count < maxProblems { result.problems.append(message) }
        else if result.problems.count == maxProblems { result.problems.append("More problems not shown.") }
    }

    static func finish<T>(_ result: inout ImportResult<T>) {
        if result.items.isEmpty && result.problems.isEmpty {
            result.problems.append("No rows could be imported. Check the column mapping.")
        }
    }
}
