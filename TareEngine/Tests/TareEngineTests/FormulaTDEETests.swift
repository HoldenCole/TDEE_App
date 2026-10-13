import XCTest
@testable import TareEngine

final class FormulaTDEETests: XCTestCase {
    let weightLb = 184.0
    var wKg: Double { Units.kg(fromLb: 184) }

    func testModeledPartsByHand() {
        let d = Dials()
        let activity = ActivityProfile(stepsPerDay: 8000, liftSessionMinutes: 60, liftStyle: "Hypertrophy", liftDaysPerWeek: 4, cardioMinutesPerDayByType: ["Run": 10])
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: activity, tef: 300, dials: d)
        XCTAssertEqual(r.dailyLiving, 180, accuracy: 1e-9)
        XCTAssertEqual(r.steps, 8000 * wKg * 0.0005, accuracy: 1e-9)
        XCTAssertEqual(r.cardio, 8.8 * wKg * 10 / 60, accuracy: 1e-9)
        XCTAssertEqual(r.lift, 4.0 * wKg * 1.0, accuracy: 1e-9)
        XCTAssertEqual(r.restDay, 1800 + 180 + r.steps + r.cardio + 300, accuracy: 1e-9)
        XCTAssertEqual(r.trainingDay, r.restDay + r.lift, accuracy: 1e-9)
        XCTAssertEqual(r.weeklyAverage(liftDaysPerWeek: 4), (r.trainingDay * 4 + r.restDay * 3) / 7, accuracy: 1e-9)
    }

    func testLiftStyleAndPostWorkoutBurn() {
        var d = Dials()
        d.postWorkoutBurnPercent = 10
        let heavy = ActivityProfile(stepsPerDay: 0, liftSessionMinutes: 90, liftStyle: "Heavy", liftDaysPerWeek: 3)
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: heavy, tef: 0, dials: d)
        XCTAssertEqual(r.lift, 2.5 * wKg * 1.5 * 1.1, accuracy: 1e-9)
    }

    func testAdaptationScalesEverythingButTEF() {
        var d = Dials()
        d.metabolicAdaptationPercent = 10
        let activity = ActivityProfile(stepsPerDay: 8000, liftSessionMinutes: 60, liftStyle: "Hypertrophy", liftDaysPerWeek: 4)
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: activity, tef: 300, dials: d)
        XCTAssertEqual(r.restDay, (1800 + 180 + r.steps) * 0.9 + 300, accuracy: 1e-9)
        XCTAssertEqual(r.trainingDay, r.restDay + r.lift * 0.9, accuracy: 1e-9)
    }

    func testWatchSourceReplacesModeledActivity() {
        var d = Dials()
        d.activitySource = .watch
        let activity = ActivityProfile(stepsPerDay: 8000, liftSessionMinutes: 60, liftStyle: "Hypertrophy", liftDaysPerWeek: 4, watchActiveRestDay: 500, watchActiveTrainingDay: 900)
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: activity, tef: 300, dials: d)
        XCTAssertEqual(r.restDay, 1800 + 180 + 500 * 0.85 + 300, accuracy: 1e-9)
        XCTAssertEqual(r.trainingDay, 1800 + 180 + 900 * 0.85 + 300, accuracy: 1e-9)
        XCTAssertNotEqual(r.restDay, r.modeledRest)
    }

    func testWatchSourceFallsBackToModeledWithoutWatchData() {
        var d = Dials()
        d.activitySource = .watch
        let activity = ActivityProfile(stepsPerDay: 8000, liftSessionMinutes: 60, liftStyle: "Hypertrophy", liftDaysPerWeek: 4)
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: activity, tef: 300, dials: d)
        XCTAssertEqual(r.restDay, r.modeledRest)
    }

    func testBlend() {
        var d = Dials()
        d.activitySource = .blend
        d.activityBlendWatchShare = 0.25
        let activity = ActivityProfile(stepsPerDay: 8000, liftSessionMinutes: 60, liftStyle: "Hypertrophy", liftDaysPerWeek: 4, watchActiveRestDay: 500, watchActiveTrainingDay: 900)
        let r = FormulaTDEE.compute(bmr: 1800, weightLb: weightLb, activity: activity, tef: 300, dials: d)
        XCTAssertEqual(r.restDay, r.modeledRest * 0.75 + r.watchRest! * 0.25, accuracy: 1e-9)
    }

    func testTEF() {
        let d = Dials()
        let expected: Double = 190.0 * 4.0 * 0.25 + 400.0 * 4.0 * 0.075 + 70.0 * 9.0 * 0.02
        XCTAssertEqual(TEF.kcal(proteinG: 190, carbsG: 400, fatG: 70, dials: d), expected, accuracy: 1e-9)
        var flat = Dials()
        flat.tefMode = .flat
        XCTAssertEqual(TEF.kcal(proteinG: 100, carbsG: 100, fatG: 100, dials: flat), 1700 * 0.10, accuracy: 1e-9)
    }

    func testActivityProfileFromLog() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0, steps: 9000, liftEvery: 2, liftMinutes: 75)
        let p = ActivityProfile.from(log: log, today: Fixture.today, dials: Fixture.dials(), calendar: Fixture.calendar)
        XCTAssertEqual(p.stepsPerDay, 9000)
        XCTAssertEqual(p.liftSessionMinutes, 75)
        XCTAssertEqual(p.liftStyle, "Hypertrophy")
        XCTAssertEqual(p.liftDaysPerWeek, 10.0 * 7 / 21, accuracy: 1e-9, "10 lift days in the 21-day window")
        XCTAssertEqual(p.daysInWindow, 21)
    }

    func testScheduleModeUsesScheduledDays() {
        var d = Fixture.dials()
        d.trainingDayDetection = .schedule
        d.scheduledTrainingWeekdays = [2, 4, 6]
        let p = ActivityProfile.from(log: [], today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(p.liftDaysPerWeek, 3)
    }

    func testFixedLiftDuration() {
        var d = Fixture.dials()
        d.liftDurationSource = .fixed
        d.fixedLiftMinutes = 45
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0, liftMinutes: 90)
        let p = ActivityProfile.from(log: log, today: Fixture.today, dials: d, calendar: Fixture.calendar)
        XCTAssertEqual(p.liftSessionMinutes, 45)
    }
}
