import XCTest
@testable import TareEngine

final class EngineTests: XCTestCase {

    func snapshot(_ log: [DayInput], _ dials: Dials) -> EngineSnapshot {
        Engine.compute(log: log, dials: dials, today: Fixture.today, calendar: Fixture.calendar)
    }

    func testBlendUsesTrustAndWindow() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let s = snapshot(log, Fixture.dials())
        XCTAssertEqual(s.targets.trust, 0.9, accuracy: 1e-9, "21 of 21 days × 90% max trust")
        XCTAssertEqual(s.targets.observedTDEE!, 3350, accuracy: 1e-6)
        let expected = 0.9 * 3350 + 0.1 * s.targets.formulaWeeklyAverage
        XCTAssertEqual(s.targets.maintenance, expected, accuracy: 1e-6)
        XCTAssertEqual(s.targets.daysLogged, 21)
    }

    func testPartialWindowLowersTrust() {
        let log = Fixture.steadyLog(days: 10, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        let s = snapshot(log, Fixture.dials())
        XCTAssertEqual(s.targets.trust, 9.0 / 21 * 0.9, accuracy: 1e-9)
    }

    func testNoDataFallsBackToFormula() {
        let s = snapshot([], Fixture.dials())
        XCTAssertEqual(s.targets.trust, 0)
        XCTAssertNil(s.targets.observedTDEE)
        XCTAssertEqual(s.targets.maintenance, s.targets.formulaWeeklyAverage, accuracy: 1e-9)
        XCTAssertFalse(s.warnings.isEmpty)
        XCTAssertGreaterThan(s.today.calories, 1000)
    }

    func testTEFLoopSettles() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        let s = snapshot(log, Fixture.dials())
        XCTAssertGreaterThan(s.targets.tef, 100)
        let macros = s.targets.weeklyAverage
        let recomputed = TEF.kcal(proteinG: macros.proteinG, carbsG: macros.carbsG, fatG: macros.fatG, dials: Fixture.dials())
        XCTAssertEqual(s.targets.tef, recomputed, accuracy: 15, "within one more pass of its fixed point")
    }

    func testTargetIsMaintenancePlusRate() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        var d = Fixture.dials()
        d.roundingKcal = 1
        let s = snapshot(log, d)
        XCTAssertEqual(s.targets.baseTarget, (s.targets.maintenance + s.targets.goalRate.dailyKcal).rounded(), accuracy: 0.51)
    }

    func testCyclingKeepsWeeklyTotal() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0, liftEvery: 2)
        var d = Fixture.dials()
        d.roundingKcal = 1
        let s = snapshot(log, d)
        let lift = s.targets.liftDaysPerWeek
        let weekly = (s.targets.training.calories * lift + s.targets.rest.calories * (7 - lift)) / 7
        XCTAssertEqual(weekly, s.targets.baseTarget, accuracy: 1.0)
        XCTAssertEqual(s.targets.training.calories - s.targets.rest.calories, s.targets.cyclingGap, accuracy: 1.0)
        XCTAssertEqual(s.targets.cyclingGap, s.targets.formulaTraining - s.targets.formulaRest, accuracy: 1e-6)
    }

    func testCyclingShiftAndOff() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        var d = Fixture.dials()
        d.cyclingShiftPercent = 50
        XCTAssertEqual(snapshot(log, d).targets.cyclingGap, (snapshot(log, d).targets.formulaTraining - snapshot(log, d).targets.formulaRest) * 0.5, accuracy: 1e-6)
        d.cyclingEnabled = false
        let off = snapshot(log, d)
        XCTAssertEqual(off.targets.training.calories, off.targets.rest.calories)
    }

    func testTrainingDayDetectionByWorkout() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        XCTAssertFalse(snapshot(log, Fixture.dials()).isTrainingDay)
        log[0].liftMinutes = 60
        let s = snapshot(log, Fixture.dials())
        XCTAssertTrue(s.isTrainingDay)
        XCTAssertEqual(s.trainingDaySource, .workout)
        XCTAssertEqual(s.today.calories, s.targets.training.calories)
    }

    func testManualOverrideWins() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        log[0].liftingOverride = true
        let s = snapshot(log, Fixture.dials())
        XCTAssertTrue(s.isTrainingDay)
        XCTAssertEqual(s.trainingDaySource, .override)
        log[0].liftingOverride = false
        log[0].liftMinutes = 60
        XCTAssertFalse(snapshot(log, Fixture.dials()).isTrainingDay)
    }

    func testScheduleDetection() {
        var d = Fixture.dials()
        d.trainingDayDetection = .schedule
        d.scheduledTrainingWeekdays = [3] // Tuesday, which Fixture.today is
        XCTAssertTrue(snapshot([], d).isTrainingDay)
        d.scheduledTrainingWeekdays = [2]
        XCTAssertFalse(snapshot([], d).isTrainingDay)
    }

    func testWeekdayOffsetAppliesToToday() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        var d = Fixture.dials()
        d.weekdayOffsets[2] = 300 // Tuesday
        let base = snapshot(log, Fixture.dials()).today.calories
        XCTAssertEqual(snapshot(log, d).today.calories, base + 300)
        XCTAssertEqual(snapshot(log, d).targets.rest.calories, snapshot(log, Fixture.dials()).targets.rest.calories, "the table ignores offsets")
    }

    func testFloorAndCeiling() {
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        var d = Fixture.dials()
        d.calorieCeiling = 2500
        let s = snapshot(log, d)
        XCTAssertEqual(s.targets.baseTarget, 2500)
        XCTAssertLessThanOrEqual(s.targets.training.calories, 2500)
        XCTAssertLessThanOrEqual(s.today.calories, 2500)
        XCTAssertTrue(s.targets.hitCeiling)
        d.calorieCeiling = nil
        d.calorieFloor = 4000
        XCTAssertEqual(snapshot(log, d).today.calories, 4000)
    }

    func testRemainingAndEaten() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        log[0].calories = 1840
        let s = snapshot(log, Fixture.dials())
        XCTAssertEqual(s.eatenCalories, 1840)
        XCTAssertEqual(s.remainingCalories, s.today.calories - 1840)
    }

    func testWeightSources() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 180, lbPerDay: 0)
        log[0].weightLb = 190
        var d = Fixture.dials()
        d.outlierThresholdLb = nil
        XCTAssertEqual(snapshot(log, d).body.weightUsedLb, 181, accuracy: 1e-9)
        d.weightSource = .latest
        XCTAssertEqual(snapshot(log, d).body.weightUsedLb, 190)
        d.weightSource = .manual
        d.manualWeightLb = 175
        XCTAssertEqual(snapshot(log, d).body.weightUsedLb, 175)
    }

    func testActualRateMatchesSyntheticSlope() {
        let log = Fixture.steadyLog(days: 60, calories: 3000, startWeight: 180, lbPerDay: -0.1)
        var d = Fixture.dials()
        d.trendAlpha = 1.0 // trend equals raw weight, so the fit is exact
        let s = snapshot(log, d)
        XCTAssertEqual(s.actualRateLbPerWeek!, -0.7, accuracy: 1e-6)
        XCTAssertEqual(s.actualRatePercentPerWeek!, -0.7 / 180 * 100, accuracy: 1e-6)
    }

    func testSensitivityIsZeroAtDefaultAndMovesWithDailyLiving() {
        let log = Fixture.steadyLog(days: 5, calories: 3000, startWeight: 180, lbPerDay: 0)
        let d = Fixture.dials()
        XCTAssertEqual(Engine.sensitivityFromDefault(log: log, dials: d, key: .dailyLivingPercent, today: Fixture.today, calendar: Fixture.calendar), 0)
        let change = Engine.targetChange(log: log, dials: d, key: .dailyLivingPercent, newValue: .number(20), today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertGreaterThan(change, 100, "10% more of a ~1,900 BMR is ~190 kcal before rounding")
        let bumped = d.with(.dailyLivingPercent, .number(20))
        XCTAssertEqual(Engine.sensitivityFromDefault(log: log, dials: bumped, key: .dailyLivingPercent, today: Fixture.today, calendar: Fixture.calendar), change)
    }

    func testSensitivityCurveIsMonotonicForStepCost() {
        let log = Fixture.steadyLog(days: 5, calories: 3000, startWeight: 180, lbPerDay: 0)
        let curve = Engine.sensitivityCurve(log: log, dials: Fixture.dials(), key: .stepCost, samples: 5, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(curve.count, 5)
        XCTAssertLessThanOrEqual(curve.first!.target, curve.last!.target)
    }

    func testHistoryLengthAndOrder() {
        let log = Fixture.steadyLog(days: 40, calories: 3000, startWeight: 180, lbPerDay: -0.05)
        let h = Engine.history(log: log, dials: Fixture.dials(), days: 10, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(h.count, 10)
        XCTAssertEqual(h.last!.date, Fixture.day(0))
        XCTAssertEqual(h.first!.date, Fixture.day(9))
        XCTAssertNotNil(h.last!.observedTDEE)
    }

    func testGoalPath() {
        let path = Engine.goalPath(from: Fixture.day(14), startWeightLb: 180, lbPerWeek: 0.7, through: Fixture.day(0), calendar: Fixture.calendar)
        XCTAssertEqual(path.count, 15)
        XCTAssertEqual(path.last!.weightLb, 181.4, accuracy: 1e-9)
    }

    func testPhaseWeek() {
        var d = Fixture.dials()
        d.phaseStartDate = Fixture.day(37)
        XCTAssertEqual(snapshot([], d).phaseWeek, 6)
    }
}
