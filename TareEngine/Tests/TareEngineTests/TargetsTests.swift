import XCTest
@testable import TareEngine

final class TargetsTests: XCTestCase {

    func testRateModes() {
        var d = Fixture.dials()
        d.ratePercentPerWeek = 0.3
        var r = GoalRate.compute(dials: d, weightLb: 184, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(r.lbPerWeek, 0.552, accuracy: 1e-9)
        XCTAssertEqual(r.dailyKcal, 0.552 * 3500 / 7, accuracy: 1e-9)

        d.rateMode = .lbPerWeek
        d.rateLbPerWeek = -1
        r = GoalRate.compute(dials: d, weightLb: 184, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(r.dailyKcal, -500, accuracy: 1e-9)
        XCTAssertEqual(r.percentPerWeek, -1 / 184 * 100, accuracy: 1e-9)

        d.rateMode = .fixedKcal
        d.fixedKcalOffset = 250
        r = GoalRate.compute(dials: d, weightLb: 184, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(r.dailyKcal, 250)
        XCTAssertEqual(r.lbPerWeek, 0.5, accuracy: 1e-9)

        d.rateMode = .goalWeightByDate
        d.goalWeightLb = 174
        d.goalDate = Fixture.calendar.date(byAdding: .day, value: 70, to: Fixture.today)
        r = GoalRate.compute(dials: d, weightLb: 184, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(r.lbPerWeek, -1, accuracy: 1e-9)
    }

    func testDialValueForLbPerWeekInversesRate() {
        var d = Fixture.dials()
        let (key, value) = GoalRate.dialValue(forLbPerWeek: 0.92, dials: d, weightLb: 184)!
        XCTAssertEqual(key, .ratePercentPerWeek)
        XCTAssertEqual(value.doubleValue!, 0.5, accuracy: 1e-9)
        d.rateMode = .fixedKcal
        XCTAssertEqual(GoalRate.dialValue(forLbPerWeek: 1, dials: d, weightLb: 184)!.value.doubleValue!, 500, accuracy: 1e-9)
    }

    func testMacros() {
        let d = Dials()
        let t = Macros.targets(calories: 3420, dayType: .training, weightLb: 184, leanMassLb: 156, trainingHours: 1, dials: d)
        XCTAssertEqual(t.proteinG, 184)
        XCTAssertEqual(t.fatG, 64)
        XCTAssertEqual(t.carbsG, ((3420 - 184 * 4 - 64 * 9) / 4).rounded())
        XCTAssertEqual(t.fiberG, (14 * 3.42).rounded())
        XCTAssertEqual(t.waterOz, (0.5 * 184 + 12).rounded())
        XCTAssertFalse(t.carbsBelowFloor)
    }

    func testMacroBasesAndFatPercent() {
        var d = Dials()
        d.proteinBasis = .leanMass
        d.fatMode = .percentOfCalories
        d.fatPercentOfCalories = 30
        let t = Macros.targets(calories: 3000, dayType: .rest, weightLb: 184, leanMassLb: 150, trainingHours: 0, dials: d)
        XCTAssertEqual(t.proteinG, 150)
        XCTAssertEqual(t.fatG, 100)
        d.proteinBasis = .goalWeight
        d.goalWeightLb = 170
        XCTAssertEqual(Macros.targets(calories: 3000, dayType: .rest, weightLb: 184, leanMassLb: nil, trainingHours: 0, dials: d).proteinG, 170)
    }

    func testCarbFloorWarning() {
        var d = Dials()
        d.carbFloorGrams = 100
        let t = Macros.targets(calories: 1600, dayType: .rest, weightLb: 184, leanMassLb: nil, trainingHours: 0, dials: d)
        XCTAssertTrue(t.carbsBelowFloor)
        XCTAssertGreaterThanOrEqual(t.carbsG, 0)
    }

    func testDayTypeOverrides() {
        var d = Dials()
        d.dayTypeOverridesEnabled = true
        d.trainingProteinGramsPerLb = 1.2
        d.restProteinGramsPerLb = 0.9
        XCTAssertEqual(Macros.targets(calories: 3000, dayType: .training, weightLb: 100, leanMassLb: nil, trainingHours: 0, dials: d).proteinG, 120)
        XCTAssertEqual(Macros.targets(calories: 3000, dayType: .rest, weightLb: 100, leanMassLb: nil, trainingHours: 0, dials: d).proteinG, 90)
        XCTAssertEqual(Macros.targets(calories: 3000, dayType: .weeklyAverage, weightLb: 100, leanMassLb: nil, trainingHours: 0, dials: d).proteinG, 100)
    }

    func testRounding() {
        XCTAssertEqual(Units.round(3417, toNearest: 10), 3420)
        XCTAssertEqual(Units.round(3417, toNearest: 25), 3425)
        XCTAssertEqual(Units.round(3417.4, toNearest: 1), 3417)
        XCTAssertEqual(Units.round(3412, toNearest: 50), 3400)
    }
}
