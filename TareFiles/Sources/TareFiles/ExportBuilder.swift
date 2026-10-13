import Foundation
import TareEngine

/// One row of the Recommendations sheet.
public struct RecommendationRow: Codable, Equatable, Sendable {
    public var date: Date
    public var rule: String
    public var headline: String
    public var status: String
    public var kcalChange: Double?
    public var detail: String

    public init(date: Date, rule: String, headline: String, status: String, kcalChange: Double? = nil, detail: String = "") {
        self.date = date
        self.rule = rule
        self.headline = headline
        self.status = status
        self.kcalChange = kcalChange
        self.detail = detail
    }
}

/// One row of the Photos sheet (dates and stats only, no images).
public struct PhotoLogRow: Codable, Equatable, Sendable {
    public var date: Date
    public var pose: String
    public var trendWeightLb: Double?
    public var bodyFatPercent: Double?
    public var phase: String

    public init(date: Date, pose: String, trendWeightLb: Double? = nil, bodyFatPercent: Double? = nil, phase: String = "") {
        self.date = date
        self.pose = pose
        self.trendWeightLb = trendWeightLb
        self.bodyFatPercent = bodyFatPercent
        self.phase = phase
    }
}

/// Builds Tare's export workbook and the blank import template.
public enum ExportBuilder {

    public static let daysSheetName = "Days"
    public static let liftsSheetName = "Lifts"
    public static let dialsSheetName = "Dials"
    public static let recommendationsSheetName = "Recommendations"
    public static let photosSheetName = "Photos"

    public static let daysColumns = ["date", "weight_lb", "body_fat_pct", "lean_mass_lb", "calories", "protein_g", "carbs_g", "fat_g", "water_oz", "steps", "active_energy_kcal", "lift_minutes", "lift_style", "cardio_minutes", "cardio_detail", "food_log_complete", "lifting_override"]
    public static let liftsColumns = ["date", "exercise", "set_index", "set_type", "weight_lb", "reps", "rpe", "source"]
    public static let dialsColumns = ["group", "key", "title", "value", "default", "unit"]
    public static let recommendationsColumns = ["date", "rule", "headline", "status", "kcal_change", "detail"]
    public static let photosColumns = ["date", "pose", "trend_weight_lb", "body_fat_pct", "phase"]

    /// The full export: Days, Lifts, Dials, Recommendations and Photos.
    public static func workbook(days: [DayInput], lifts: [LiftSetInput], dials: Dials, recommendations: [RecommendationRow], photos: [PhotoLogRow]) -> Workbook {
        Workbook(sheets: [
            Sheet(name: daysSheetName, table: daysTable(days)),
            Sheet(name: liftsSheetName, table: liftsTable(lifts)),
            Sheet(name: dialsSheetName, table: dialsTable(dials)),
            Sheet(name: recommendationsSheetName, table: recommendationsTable(recommendations)),
            Sheet(name: photosSheetName, table: photosTable(photos)),
        ])
    }

    /// A blank workbook with Days and Lifts headers and one example row each.
    public static func template() -> Workbook {
        let today = Calendar.current.startOfDay(for: Date())
        let day = DayInput(date: today, weightLb: 184.6, bodyFatPercent: 18.5, leanMassLb: nil, calories: 2650, proteinG: 190, carbsG: 290, fatG: 80, waterOz: 100, steps: 8500, activeEnergyKcal: 520, liftMinutes: 60, liftStyle: "Hypertrophy", cardioSessions: [CardioSession(type: "Walk", minutes: 30)], foodLogComplete: true, liftingOverride: nil)
        let set = LiftSetInput(date: today, exercise: "Bench Press (Barbell)", setIndex: 0, setType: .working, weightLb: 225, reps: 5, rpe: 8, source: "Template")
        return Workbook(sheets: [
            Sheet(name: daysSheetName, table: daysTable([day])),
            Sheet(name: liftsSheetName, table: liftsTable([set])),
        ])
    }

    // MARK: Tables

    public static func daysTable(_ days: [DayInput]) -> Table {
        var table = Table(columns: daysColumns)
        for d in days.sorted(by: { $0.date < $1.date }) {
            table.append([
                day(d.date),
                number(d.weightLb),
                number(d.bodyFatPercent),
                number(d.leanMassLb),
                number(d.calories),
                number(d.proteinG),
                number(d.carbsG),
                number(d.fatG),
                number(d.waterOz),
                d.steps.map(String.init) ?? "",
                number(d.activeEnergyKcal),
                number(d.liftMinutes),
                d.liftStyle ?? "",
                d.cardioSessions.isEmpty ? "" : number(d.totalCardioMinutes),
                ImportParser.cardioDetail(d.cardioSessions),
                d.foodLogComplete ? "true" : "false",
                d.liftingOverride.map { $0 ? "true" : "false" } ?? "",
            ])
        }
        return table
    }

    public static func liftsTable(_ lifts: [LiftSetInput]) -> Table {
        var table = Table(columns: liftsColumns)
        for s in lifts {
            table.append([
                day(s.date),
                s.exercise,
                String(s.setIndex),
                s.setType.rawValue,
                number(s.weightLb),
                String(s.reps),
                number(s.rpe),
                s.source,
            ])
        }
        return table
    }

    public static func dialsTable(_ dials: Dials) -> Table {
        var table = Table(columns: dialsColumns)
        for spec in DialCatalog.specs(for: dials) {
            table.append([
                spec.group.title,
                spec.key.rawValue,
                spec.title,
                dials.value(for: spec.key).compactDescription,
                spec.defaultValue.compactDescription,
                spec.unit,
            ])
        }
        return table
    }

    public static func recommendationsTable(_ rows: [RecommendationRow]) -> Table {
        var table = Table(columns: recommendationsColumns)
        for r in rows {
            table.append([day(r.date), r.rule, r.headline, r.status, number(r.kcalChange), r.detail])
        }
        return table
    }

    public static func photosTable(_ rows: [PhotoLogRow]) -> Table {
        var table = Table(columns: photosColumns)
        for r in rows {
            table.append([day(r.date), r.pose, number(r.trendWeightLb), number(r.bodyFatPercent), r.phase])
        }
        return table
    }

    // MARK: Formatting

    /// `yyyy-MM-dd` in the current time zone.
    public static func day(_ date: Date) -> String { DateParsing.dayString(date) }

    /// Shortest round-trip text for a number; whole numbers without a decimal point.
    public static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let rounded = (value * 1e6).rounded() / 1e6
        return "\(rounded)"
    }
}
