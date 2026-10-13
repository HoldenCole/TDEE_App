import XCTest
import TareEngine
@testable import TareFiles

final class ExportRoundTripTests: XCTestCase {

    private func day(_ s: String) -> Date { DateParsing.date(s)! }

    func testWorkbookHasExpectedSheets() throws {
        let dials = Dials()
        let wb = ExportBuilder.workbook(days: [], lifts: [], dials: dials,
                                        recommendations: [RecommendationRow(date: day("2026-10-13"), rule: "slow", headline: "Hold", status: "applied", kcalChange: -100, detail: "d")],
                                        photos: [PhotoLogRow(date: day("2026-10-13"), pose: "front", trendWeightLb: 184.2, bodyFatPercent: 18.1, phase: "cut")])
        XCTAssertEqual(wb.sheets.map(\.name), ["Days", "Lifts", "Dials", "Recommendations", "Photos"])
        XCTAssertEqual(wb.sheets[0].table.columns, ExportBuilder.daysColumns)
        XCTAssertEqual(wb.sheets[1].table.columns, ExportBuilder.liftsColumns)
        XCTAssertEqual(wb.sheets[2].table.columns, ["group", "key", "title", "value", "default", "unit"])
        XCTAssertEqual(wb.sheets[2].table.rows.count, DialCatalog.specs(for: dials).count)
        XCTAssertTrue(wb.sheets[2].table.rows.contains { $0[1] == DialKey.sex.rawValue })
        XCTAssertEqual(wb.sheets[3].table.rows, [["2026-10-13", "slow", "Hold", "applied", "-100", "d"]])
        XCTAssertEqual(wb.sheets[4].table.rows, [["2026-10-13", "front", "184.2", "18.1", "cut"]])

        let data = try XLSX.write(wb)
        let back = try XLSX.read(data)
        XCTAssertEqual(back.sheets.map(\.name), wb.sheets.map(\.name))
        XCTAssertEqual(back.sheets[2].table.rows.count, wb.sheets[2].table.rows.count)
    }

    func testTemplate() throws {
        let t = ExportBuilder.template()
        XCTAssertEqual(t.sheets.map(\.name), ["Days", "Lifts"])
        XCTAssertEqual(t.sheets[0].table.rows.count, 1)
        XCTAssertEqual(t.sheets[1].table.rows.count, 1)
        let back = try XLSX.read(try XLSX.write(t))
        XCTAssertEqual(back.sheets[0].table.columns, ExportBuilder.daysColumns)
        let days = ImportParser.days(from: back.sheets[0].table, mapping: MappingGuesser.guess(columns: back.sheets[0].table.columns))
        XCTAssertEqual(days.items.count, 1)
        XCTAssertEqual(days.items[0].weightLb, 184.6)
    }

    func testDaysRoundTrip() throws {
        let days = [
            DayInput(date: day("2026-10-13"), weightLb: 184.6, bodyFatPercent: 18.5, leanMassLb: 150.45, calories: 2650, proteinG: 190, carbsG: 290.5, fatG: 80, waterOz: 100, steps: 8500, activeEnergyKcal: 520, liftMinutes: 60, liftStyle: "Hypertrophy", cardioSessions: [CardioSession(type: "Walk", minutes: 30), CardioSession(type: "Bike", minutes: 20.5)], foodLogComplete: true, liftingOverride: nil),
            DayInput(date: day("2026-10-14"), weightLb: 183.9, calories: 2400, foodLogComplete: false, liftingOverride: true),
            DayInput(date: day("2026-10-15"), weightLb: nil, calories: nil, steps: 12000, liftingOverride: false),
        ]
        let lifts = [
            LiftSetInput(date: day("2026-10-13"), exercise: "Bench Press (Barbell)", setIndex: 0, setType: .warmup, weightLb: 135, reps: 10, rpe: nil, source: "Hevy"),
            LiftSetInput(date: day("2026-10-13"), exercise: "Bench Press (Barbell)", setIndex: 1, setType: .working, weightLb: 225, reps: 5, rpe: 8, source: "Hevy"),
            LiftSetInput(date: day("2026-10-14"), exercise: "Deadlift, conventional", setIndex: 0, setType: .failure, weightLb: 315.5, reps: 3, rpe: 9.5, source: "Strong"),
        ]
        let wb = ExportBuilder.workbook(days: days, lifts: lifts, dials: Dials(), recommendations: [], photos: [])
        let data = try XLSX.write(wb)
        let back = try XLSX.read(data)

        let daysTable = back.sheet(named: "Days")!.table
        let mapping = MappingGuesser.guess(columns: daysTable.columns)
        let result = ImportParser.days(from: daysTable, mapping: mapping)
        XCTAssertEqual(result.problems, [])
        XCTAssertEqual(result.skippedRows, 0)
        XCTAssertEqual(result.items.count, days.count)
        for (original, imported) in zip(days, result.items) {
            XCTAssertEqual(Calendar.current.startOfDay(for: original.date), Calendar.current.startOfDay(for: imported.date))
            XCTAssertEqual(original.weightLb, imported.weightLb)
            XCTAssertEqual(original.bodyFatPercent, imported.bodyFatPercent)
            XCTAssertEqual(original.leanMassLb, imported.leanMassLb)
            XCTAssertEqual(original.calories, imported.calories)
            XCTAssertEqual(original.proteinG, imported.proteinG)
            XCTAssertEqual(original.carbsG, imported.carbsG)
            XCTAssertEqual(original.fatG, imported.fatG)
            XCTAssertEqual(original.waterOz, imported.waterOz)
            XCTAssertEqual(original.steps, imported.steps)
            XCTAssertEqual(original.activeEnergyKcal, imported.activeEnergyKcal)
            XCTAssertEqual(original.liftMinutes, imported.liftMinutes)
            XCTAssertEqual(original.liftStyle, imported.liftStyle)
            XCTAssertEqual(original.cardioSessions, imported.cardioSessions)
            XCTAssertEqual(original.foodLogComplete, imported.foodLogComplete)
            XCTAssertEqual(original.liftingOverride, imported.liftingOverride)
        }
        // Whole-struct equality holds too, since exported dates are local midnight.
        XCTAssertEqual(result.items, days)

        let liftsTable = back.sheet(named: "Lifts")!.table
        let liftMapping = MappingGuesser.guess(columns: liftsTable.columns)
        let liftResult = ImportParser.liftSets(from: liftsTable, mapping: liftMapping, source: "Tare")
        XCTAssertEqual(liftResult.items.count, lifts.count)
        for (original, imported) in zip(lifts, liftResult.items) {
            XCTAssertEqual(Calendar.current.startOfDay(for: original.date), Calendar.current.startOfDay(for: imported.date))
            XCTAssertEqual(original.exercise, imported.exercise)
            XCTAssertEqual(original.setIndex, imported.setIndex)
            XCTAssertEqual(original.setType, imported.setType)
            XCTAssertEqual(original.weightLb, imported.weightLb)
            XCTAssertEqual(original.reps, imported.reps)
            XCTAssertEqual(original.rpe, imported.rpe)
        }
    }

    func testCSVRoundTripOfDaysSheet() {
        let days = [DayInput(date: day("2026-10-13"), weightLb: 184.6, calories: 2650, cardioSessions: [CardioSession(type: "Run", minutes: 30)])]
        let csv = CSV.write(ExportBuilder.daysTable(days))
        let table = CSV.parse(csv)
        let result = ImportParser.days(from: table, mapping: MappingGuesser.guess(columns: table.columns))
        XCTAssertEqual(result.items, days)
    }
}
