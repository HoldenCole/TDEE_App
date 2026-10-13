import XCTest
import TareEngine
@testable import TareFiles

final class ImportParserTests: XCTestCase {

    private func ymd(_ date: Date) -> String { DateParsing.dayString(date) }

    func testNumberParsing() {
        XCTAssertEqual(NumberParsing.double("184.6 lb"), 184.6)
        XCTAssertEqual(NumberParsing.double("+2,650"), 2650)
        XCTAssertEqual(NumberParsing.double("1,234.5"), 1234.5)
        XCTAssertEqual(NumberParsing.double("1.234,5"), 1234.5)
        XCTAssertEqual(NumberParsing.double("184,6"), 184.6)
        XCTAssertEqual(NumberParsing.double("18.5%"), 18.5)
        XCTAssertEqual(NumberParsing.double("-3"), -3)
        XCTAssertEqual(NumberParsing.double("1e3"), 1000)
        XCTAssertNil(NumberParsing.double(""))
        XCTAssertNil(NumberParsing.double("abc"))
        XCTAssertEqual(NumberParsing.int("8,500"), 8500)
        XCTAssertEqual(NumberParsing.bool("Yes"), true)
        XCTAssertEqual(NumberParsing.bool("0"), false)
        XCTAssertNil(NumberParsing.bool("maybe"))
    }

    func testDateParsing() {
        func day(_ s: String) -> String? { DateParsing.date(s).map(ymd) }
        XCTAssertEqual(day("2026-10-13"), "2026-10-13")
        XCTAssertEqual(day("2026-10-13 07:15:00"), "2026-10-13")
        XCTAssertEqual(day("2026-10-13T07:15:00"), "2026-10-13")
        XCTAssertEqual(day("13 Oct 2026, 07:15"), "2026-10-13")
        XCTAssertEqual(day("13 Oct 2026"), "2026-10-13")
        XCTAssertEqual(day("Oct 13, 2026"), "2026-10-13")
        XCTAssertEqual(day("10/13/2026"), "2026-10-13")
        XCTAssertEqual(day("13/10/2026"), "2026-10-13")
        XCTAssertEqual(day("3/4/2026"), "2026-03-04") // ambiguous → M/d
        XCTAssertEqual(day("10/13/2026 7:15:00 AM"), "2026-10-13")
        XCTAssertEqual(day("13.10.2026"), "2026-10-13")
        XCTAssertEqual(day("20261013"), "2026-10-13")
        XCTAssertNil(day(""))
        XCTAssertNil(day("not a date"))

        // ISO with offset and fractional seconds resolve to the exact instant.
        let iso = DateParsing.date("2026-10-13T07:15:00+00:00")
        XCTAssertEqual(iso?.timeIntervalSince1970, 1791875700)
        XCTAssertEqual(DateParsing.date("2026-10-13T07:15:00.250Z")?.timeIntervalSince1970, 1791875700.25)
        XCTAssertEqual(DateParsing.date("2026-10-13 07:15:00 +0000")?.timeIntervalSince1970, 1791875700)

        // Custom formats go first.
        XCTAssertEqual(DateParsing.date("13|10|2026", extraFormats: ["dd|MM|yyyy"]).map(ymd), "2026-10-13")
    }

    func testHevyCSV() {
        let csv = """
        title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_lbs,reps,distance_miles,duration_seconds,rpe
        "Push Day","13 Oct 2026, 07:15","13 Oct 2026, 08:20","","Bench Press (Barbell)","","",0,warmup,135,10,,,
        "Push Day","13 Oct 2026, 07:15","13 Oct 2026, 08:20","","Bench Press (Barbell)","","",1,normal,225,5,,,8
        "Push Day","13 Oct 2026, 07:15","13 Oct 2026, 08:20","","Bench Press (Barbell)","","",2,dropset,185,8,,,9.5

        """
        let table = CSV.parse(csv)
        let mapping = MappingGuesser.guess(columns: table.columns)
        let result = ImportParser.liftSets(from: table, mapping: mapping)
        XCTAssertEqual(result.skippedRows, 0)
        XCTAssertEqual(result.problems, [])
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items.map { ymd($0.date) }, ["2026-10-13", "2026-10-13", "2026-10-13"])
        XCTAssertEqual(result.items.map(\.exercise), Array(repeating: "Bench Press (Barbell)", count: 3))
        XCTAssertEqual(result.items.map(\.setIndex), [0, 1, 2])
        XCTAssertEqual(result.items.map(\.setType), [.warmup, .working, .drop])
        XCTAssertEqual(result.items.map(\.weightLb), [135, 225, 185])
        XCTAssertEqual(result.items.map(\.reps), [10, 5, 8])
        XCTAssertEqual(result.items.map(\.rpe), [nil, 8, 9.5])
        XCTAssertEqual(result.items.map(\.source), ["Hevy", "Hevy", "Hevy"])
        let hour = Calendar.current.component(.hour, from: result.items[0].date)
        XCTAssertEqual(hour, 7)
    }

    func testHevyCSVInKilograms() {
        let csv = """
        title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe
        "Pull","14 Oct 2026, 06:00","14 Oct 2026, 07:00","","Deadlift (Barbell)","","",0,normal,100,5,,,8
        """
        let table = CSV.parse(csv)
        let result = ImportParser.liftSets(from: table, mapping: MappingGuesser.guess(columns: table.columns))
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].weightLb, Units.lb(fromKg: 100), accuracy: 0.0001)
    }

    func testStrongCSV() {
        let csv = """
        Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
        2026-10-13 07:15:00,Push Day,1h 5m,Bench Press (Barbell),1,135,10,0,0,,,
        2026-10-13 07:15:00,Push Day,1h 5m,Bench Press (Barbell),Rest Timer,,,,,,,
        2026-10-13 07:15:00,Push Day,1h 5m,Bench Press (Barbell),2,225,5,0,0,,,8
        2026-10-13 07:15:00,Push Day,1h 5m,Bench Press (Barbell),Note,,,,,"felt good",,
        2026-10-14 06:00:00,Pull Day,55m,Deadlift (Barbell),1,140,5,0,0,,,9
        """
        let table = CSV.parse(csv)
        let mapping = MappingGuesser.guess(columns: table.columns)
        let result = ImportParser.liftSets(from: table, mapping: mapping, options: ImportOptions(weightUnit: .kg))
        XCTAssertEqual(result.skippedRows, 2)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items.map { ymd($0.date) }, ["2026-10-13", "2026-10-13", "2026-10-14"])
        XCTAssertEqual(result.items.map(\.setIndex), [1, 2, 1])
        XCTAssertEqual(result.items.map(\.setType), [.working, .working, .working])
        XCTAssertEqual(result.items[0].weightLb, Units.lb(fromKg: 135), accuracy: 0.0001)
        XCTAssertEqual(result.items[2].weightLb, Units.lb(fromKg: 140), accuracy: 0.0001)
        XCTAssertEqual(result.items.map(\.reps), [10, 5, 5])
        XCTAssertEqual(result.items.map(\.rpe), [nil, 8, 9])
        XCTAssertEqual(result.items.map(\.exercise), ["Bench Press (Barbell)", "Bench Press (Barbell)", "Deadlift (Barbell)"])
        XCTAssertEqual(result.items.map(\.source), ["Strong", "Strong", "Strong"])

        let inPounds = ImportParser.liftSets(from: table, mapping: mapping, options: ImportOptions(weightUnit: .lb), source: "Custom")
        XCTAssertEqual(inPounds.items[0].weightLb, 135)
        XCTAssertEqual(inPounds.items[0].source, "Custom")
    }

    func testRunningSetIndexAndSetTypeWords() {
        let table = Table(columns: ["Date", "Exercise", "Weight (kg)", "Reps", "Type"], rows: [
            ["2026-10-13", "Squat", "100", "5", "Warm-up"],
            ["2026-10-13", "Squat", "140", "5", "working"],
            ["2026-10-13", "Squat", "120", "8", "drop"],
            ["2026-10-13", "Press", "60", "8", "FAILURE"],
            ["2026-10-13", "Press", "60", "x", ""],
        ])
        let mapping = MappingGuesser.guess(columns: table.columns)
        XCTAssertEqual(mapping["Weight (kg)"], .setWeight)
        XCTAssertEqual(mapping["Type"], .setType)
        let result = ImportParser.liftSets(from: table, mapping: mapping)
        XCTAssertEqual(result.items.map(\.setIndex), [0, 1, 2, 0])
        XCTAssertEqual(result.items.map(\.setType), [.warmup, .working, .drop, .failure])
        XCTAssertEqual(result.items[0].weightLb, Units.lb(fromKg: 100), accuracy: 0.0001)
        XCTAssertEqual(result.skippedRows, 1)
        XCTAssertEqual(result.items[0].source, "Import")
    }

    func testDaysMergeAndUnits() {
        let table = Table(columns: ["Date", "Weight (kg)", "Calories", "Protein (g)", "Steps", "Body Fat %", "Logged"], rows: [
            ["10/13/2026", "80", "2,600", "180", "8,500", "0.185", "yes"],
            ["10/13/2026", "", "+2650", "", "", "", ""],
            ["10/14/2026", "79.5 kg", "", "", "9000", "18", "no"],
            ["garbage", "1", "", "", "", "", ""],
        ])
        let mapping = MappingGuesser.guess(columns: table.columns)
        XCTAssertEqual(mapping["Logged"], .foodLogComplete)
        let result = ImportParser.days(from: table, mapping: mapping)
        XCTAssertEqual(result.skippedRows, 1)
        XCTAssertEqual(result.problems.count, 1)
        XCTAssertEqual(result.items.count, 2)
        let d1 = result.items[0], d2 = result.items[1]
        XCTAssertEqual(ymd(d1.date), "2026-10-13")
        XCTAssertEqual(d1.weightLb!, Units.lb(fromKg: 80), accuracy: 0.0001)
        XCTAssertEqual(d1.calories, 2650) // later row overrides
        XCTAssertEqual(d1.proteinG, 180)  // earlier value kept when later is blank
        XCTAssertEqual(d1.steps, 8500)
        XCTAssertEqual(d1.bodyFatPercent, 18.5)
        XCTAssertEqual(d1.foodLogComplete, true)
        XCTAssertEqual(ymd(d2.date), "2026-10-14")
        XCTAssertEqual(d2.weightLb!, Units.lb(fromKg: 79.5), accuracy: 0.0001)
        XCTAssertEqual(d2.bodyFatPercent, 18)
        XCTAssertEqual(d2.foodLogComplete, false)
        XCTAssertEqual(d2.date, Calendar.current.startOfDay(for: d2.date))
    }

    func testCardioDetail() {
        XCTAssertEqual(ImportParser.parseCardioDetail("Run:30;Bike:20.5"), [CardioSession(type: "Run", minutes: 30), CardioSession(type: "Bike", minutes: 20.5)])
        XCTAssertEqual(ImportParser.parseCardioDetail("Walk 45"), [CardioSession(type: "Walk", minutes: 45)])
        XCTAssertEqual(ImportParser.cardioDetail([CardioSession(type: "Run", minutes: 30), CardioSession(type: "Bike", minutes: 20.5)]), "Run:30;Bike:20.5")
    }
}
