import XCTest
@testable import TareEngine

final class ObservedTDEETests: XCTestCase {

    /// 28 days of 3,000 kcal with weight falling 0.1 lb a day: observed TDEE must be 3,000 + 350.
    func testSyntheticLogRecoversKnownTDEE() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let r = ObservedTDEE.compute(log: log, today: Fixture.today, dials: Fixture.dials(), calendar: Fixture.calendar)
        XCTAssertEqual(r.daysWithCalories, 21, "calorie window is the 21 days ending yesterday")
        XCTAssertEqual(r.daysWithWeight, 21, "weigh-in window is the 21 days ending today")
        XCTAssertEqual(r.slopeLbPerDay!, -0.1, accuracy: 1e-9)
        XCTAssertEqual(r.meanIntake!, 3000, accuracy: 1e-9)
        XCTAssertEqual(r.value!, 3350, accuracy: 1e-6)
    }

    func testGainingLowersObserved() {
        let log = Fixture.steadyLog(days: 28, calories: 3400, startWeight: 184, lbPerDay: 0.05)
        let r = ObservedTDEE.compute(log: log, today: Fixture.today, dials: Fixture.dials(), calendar: Fixture.calendar)
        XCTAssertEqual(r.value!, 3400 - 0.05 * 3500, accuracy: 1e-6)
    }

    func testEnergyPerLbDialIsUsed() {
        var d = Fixture.dials()
        d.kcalPerLb = 2500
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let r = ObservedTDEE.compute(log: log, today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(r.value!, 3250, accuracy: 1e-6)
    }

    func testNeedsSevenDaysOfEach() {
        let log = Fixture.steadyLog(days: 6, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let r = ObservedTDEE.compute(log: log, today: Fixture.today, dials: Fixture.dials(), calendar: Fixture.calendar)
        XCTAssertNil(r.value)
        XCTAssertFalse(r.isAvailable)
    }

    func testIncompleteDaysExcludedByDefaultIncludedByDial() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        for i in 1...5 {
            log[i].calories = 1000
            log[i].foodLogComplete = false
        }
        var d = Fixture.dials()
        let excluded = ObservedTDEE.compute(log: log, today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(excluded.daysWithCalories, 16)
        XCTAssertEqual(excluded.value!, 3350, accuracy: 1e-6)

        d.incompleteFoodDays = .include
        let included = ObservedTDEE.compute(log: log, today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(included.daysWithCalories, 21)
        XCTAssertLessThan(included.value!, 3350)
    }

    func testTrustWindowDialChangesWindow() {
        var d = Fixture.dials()
        d.trustWindowDays = 14
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let r = ObservedTDEE.compute(log: log, today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(r.daysWithCalories, 14)
        XCTAssertEqual(r.windowDays, 14)
    }
}
