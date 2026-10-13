import XCTest
@testable import TareFiles

final class MappingTests: XCTestCase {

    static let hevyHeader = "title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_lbs,reps,distance_miles,duration_seconds,rpe".split(separator: ",").map(String.init)
    static let strongHeader = "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE".split(separator: ",").map(String.init)
    static let macroFactorHeader = "Date,Weight (lb),Calories,Protein (g),Carbs (g),Fat (g),Steps".split(separator: ",").map(String.init)

    func testHevyHeader() {
        let m = MappingGuesser.guess(columns: Self.hevyHeader)
        XCTAssertEqual(m["title"], .workoutTitle)
        XCTAssertEqual(m["start_time"], .workoutStart)
        XCTAssertEqual(m["end_time"], .workoutEnd)
        XCTAssertEqual(m["description"], .ignore)
        XCTAssertEqual(m["exercise_title"], .exercise)
        XCTAssertEqual(m["superset_id"], .ignore)
        XCTAssertEqual(m["exercise_notes"], .ignore)
        XCTAssertEqual(m["set_index"], .setIndex)
        XCTAssertEqual(m["set_type"], .setType)
        XCTAssertEqual(m["weight_lbs"], .setWeight)
        XCTAssertEqual(m["reps"], .reps)
        XCTAssertEqual(m["distance_miles"], .ignore)
        XCTAssertEqual(m["duration_seconds"], .ignore)
        XCTAssertEqual(m["rpe"], .rpe)
        XCTAssertEqual(MappingGuesser.detectSource(columns: Self.hevyHeader), "Hevy")

        var kg = Self.hevyHeader
        kg[9] = "weight_kg"
        XCTAssertEqual(MappingGuesser.guess(columns: kg)["weight_kg"], .setWeight)
        XCTAssertEqual(MappingGuesser.detectSource(columns: kg), "Hevy")
    }

    func testStrongHeader() {
        let m = MappingGuesser.guess(columns: Self.strongHeader)
        XCTAssertEqual(m["Date"], .date)
        XCTAssertEqual(m["Workout Name"], .workoutTitle)
        XCTAssertEqual(m["Duration"], .ignore)
        XCTAssertEqual(m["Exercise Name"], .exercise)
        XCTAssertEqual(m["Set Order"], .setIndex)
        XCTAssertEqual(m["Weight"], .setWeight)
        XCTAssertEqual(m["Reps"], .reps)
        XCTAssertEqual(m["Distance"], .ignore)
        XCTAssertEqual(m["Seconds"], .ignore)
        XCTAssertEqual(m["Notes"], .ignore)
        XCTAssertEqual(m["Workout Notes"], .ignore)
        XCTAssertEqual(m["RPE"], .rpe)
        XCTAssertEqual(MappingGuesser.detectSource(columns: Self.strongHeader), "Strong")
        XCTAssertTrue(m.describesLifts)
    }

    func testMacroFactorLikeHeader() {
        let m = MappingGuesser.guess(columns: Self.macroFactorHeader)
        XCTAssertEqual(m["Date"], .date)
        XCTAssertEqual(m["Weight (lb)"], .weight)
        XCTAssertEqual(m["Calories"], .calories)
        XCTAssertEqual(m["Protein (g)"], .protein)
        XCTAssertEqual(m["Carbs (g)"], .carbs)
        XCTAssertEqual(m["Fat (g)"], .fat)
        XCTAssertEqual(m["Steps"], .steps)
        XCTAssertEqual(MappingGuesser.detectSource(columns: Self.macroFactorHeader), "MacroFactor")
        XCTAssertFalse(m.describesLifts)
    }

    func testTareDaysHeader() {
        let m = MappingGuesser.guess(columns: ExportBuilder.daysColumns)
        let expected: [String: ImportField] = [
            "date": .date, "weight_lb": .weight, "body_fat_pct": .bodyFat, "lean_mass_lb": .leanMass,
            "calories": .calories, "protein_g": .protein, "carbs_g": .carbs, "fat_g": .fat, "water_oz": .water,
            "steps": .steps, "active_energy_kcal": .activeEnergy, "lift_minutes": .liftMinutes, "lift_style": .liftStyle,
            "cardio_minutes": .cardioMinutes, "cardio_detail": .cardioDetail, "food_log_complete": .foodLogComplete,
            "lifting_override": .liftingOverride,
        ]
        XCTAssertEqual(m.fields, expected)
        XCTAssertEqual(MappingGuesser.detectSource(columns: ExportBuilder.daysColumns), "Tare")
    }

    func testTareLiftsHeader() {
        let m = MappingGuesser.guess(columns: ExportBuilder.liftsColumns)
        XCTAssertEqual(m["date"], .date)
        XCTAssertEqual(m["exercise"], .exercise)
        XCTAssertEqual(m["set_index"], .setIndex)
        XCTAssertEqual(m["set_type"], .setType)
        XCTAssertEqual(m["weight_lb"], .setWeight)
        XCTAssertEqual(m["reps"], .reps)
        XCTAssertEqual(m["rpe"], .rpe)
        XCTAssertEqual(m["source"], .ignore)
        XCTAssertEqual(MappingGuesser.detectSource(columns: ExportBuilder.liftsColumns), "Tare")
    }

    func testMiscellaneousNames() {
        let m = MappingGuesser.guess(columns: ["Day", "Body weight (lb)", "Energy (kcal)", "Active Energy", "Body Fat %", "Lean Body Mass", "Water (oz)", "Step Count", "Completed"])
        XCTAssertEqual(m["Day"], .date)
        XCTAssertEqual(m["Body weight (lb)"], .weight)
        XCTAssertEqual(m["Energy (kcal)"], .calories)
        XCTAssertEqual(m["Active Energy"], .activeEnergy)
        XCTAssertEqual(m["Body Fat %"], .bodyFat)
        XCTAssertEqual(m["Lean Body Mass"], .leanMass)
        XCTAssertEqual(m["Water (oz)"], .water)
        XCTAssertEqual(m["Step Count"], .steps)
        XCTAssertEqual(m["Completed"], .foodLogComplete)
        XCTAssertEqual(MappingGuesser.detectSource(columns: ["Day", "Energy (kcal)", "Protein (g)", "Completed"]), "Cronometer")
        XCTAssertEqual(MappingGuesser.detectSource(columns: ["Date", "Meal", "Calories", "Fat (g)"]), "MyFitnessPal")
        XCTAssertNil(MappingGuesser.detectSource(columns: ["foo", "bar"]))
    }

    func testDuplicateFieldsOnlyMappedOnce() {
        let m = MappingGuesser.guess(columns: ["Date", "Weight", "Weight (kg)"])
        XCTAssertEqual(m["Weight"], .weight)
        XCTAssertEqual(m["Weight (kg)"], .ignore)
    }

    func testMappingIsCodable() throws {
        let m = ColumnMapping(fields: ["Date": .date, "Weight": .weight])
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(ColumnMapping.self, from: data), m)
        XCTAssertEqual(ImportField.allCases.count, 27)
        for f in ImportField.allCases { XCTAssertFalse(f.title.isEmpty) }
    }
}
