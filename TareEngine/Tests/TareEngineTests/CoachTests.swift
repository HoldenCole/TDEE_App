import XCTest
@testable import TareEngine

final class CoachTests: XCTestCase {

    func report(_ log: [DayInput], _ dials: Dials, sets: [LiftSetInput] = [], previousMisses: Int = 0) -> CoachReport {
        Coach.evaluate(context: CoachContext(log: log, liftSets: sets, previousRateMisses: previousMisses), dials: dials, today: Fixture.today, calendar: Fixture.calendar)
    }

    /// Bulking at +0.30%/wk but gaining nothing: the rate rule fires once the streak is long enough.
    func testRateOffTargetNeedsTwoMissesAndProposesCappedChange() {
        var d = Fixture.dials()
        d.trendAlpha = 1.0
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0)

        let first = report(log, d)
        XCTAssertTrue(first.rateMissedThisCheckIn)
        XCTAssertEqual(first.consecutiveRateMisses, 1)
        XCTAssertFalse(first.recommendations.contains { $0.rule == .rateOffTarget }, "one miss isn't enough")

        let second = report(log, d, previousMisses: 1)
        XCTAssertEqual(second.consecutiveRateMisses, 2)
        let rec = second.recommendations.first { $0.rule == .rateOffTarget }
        XCTAssertNotNil(rec)
        let goalLb = 0.3 / 100 * 184
        let raw = goalLb * 3500 / 7
        XCTAssertGreaterThan(raw, 250, "the synthetic gap is bigger than the cap")
        let expected = 250.0
        XCTAssertEqual(rec!.kcalChange!, expected, accuracy: 1e-9)
        XCTAssertTrue(rec!.headline.hasPrefix("Raise your target by"))
        XCTAssertEqual(rec!.proposals.first?.key, .ratePercentPerWeek)
        let newPct = rec!.proposals.first!.newValue.doubleValue!
        XCTAssertEqual(newPct, (goalLb + expected * 7 / 3500) / 184 * 100, accuracy: 0.01)
        XCTAssertNotNil(rec!.chart)
        XCTAssertEqual(rec!.chart!.series.count, 2)
    }

    func testRateChangeIsCapped() {
        var d = Fixture.dials()
        d.trendAlpha = 1.0
        d.rateMode = .lbPerWeek
        d.rateLbPerWeek = 2.0
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0)
        let rec = report(log, d, previousMisses: 1).recommendations.first { $0.rule == .rateOffTarget }!
        XCTAssertEqual(rec.kcalChange!, 250)
    }

    func testOnTargetDoesNotFire() {
        var d = Fixture.dials()
        d.trendAlpha = 1.0
        d.rateMode = .lbPerWeek
        d.rateLbPerWeek = 0.7
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0.1)
        let r = report(log, d, previousMisses: 5)
        XCTAssertFalse(r.rateMissedThisCheckIn)
        XCTAssertEqual(r.consecutiveRateMisses, 0)
        XCTAssertTrue(r.recommendations.filter { $0.rule == .rateOffTarget }.isEmpty)
    }

    func testIncompleteLoggingHoldsCalorieChanges() {
        var d = Fixture.dials()
        d.trendAlpha = 1.0
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0)
        for i in 1...4 { log[i].calories = nil }
        let r = report(log, d, previousMisses: 3)
        let hold = r.recommendations.first { $0.rule == .incompleteLogging }
        XCTAssertNotNil(hold)
        XCTAssertTrue(hold!.holdsCalorieChanges)
        XCTAssertFalse(hold!.hasProposal)
        XCTAssertTrue(r.recommendations.filter { $0.rule == .rateOffTarget }.isEmpty, "held")
        XCTAssertTrue(r.rateMissedThisCheckIn, "the streak still counts")
    }

    func testStrengthDroppingOnCut() {
        var d = Fixture.dials()
        d.phase = .cut
        d.ratePercentPerWeek = -0.75
        d.exerciseUnlockSessions = 2
        var sets: [LiftSetInput] = []
        for ex in ["Bench Press", "Back Squat", "Deadlift"] {
            sets.append(LiftSetInput(date: Fixture.day(27), exercise: ex, setIndex: 1, weightLb: 300, reps: 5))
            sets.append(LiftSetInput(date: Fixture.day(2), exercise: ex, setIndex: 1, weightLb: 270, reps: 5))
        }
        let log = Fixture.steadyLog(days: 28, calories: 2200, startWeight: 184, lbPerDay: -0.2)
        let rec = report(log, d, sets: sets).recommendations.first { $0.rule == .strengthDropping }
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec!.proposals.first!.key, .ratePercentPerWeek)
        XCTAssertEqual(rec!.proposals.first!.newValue.doubleValue!, -0.5, accuracy: 0.01)
        XCTAssertGreaterThan(rec!.kcalChange!, 0)

        d.phase = .leanBulk
        XCTAssertNil(report(log, d, sets: sets).recommendations.first { $0.rule == .strengthDropping }, "only on a cut")
    }

    func testLongCut() {
        var d = Fixture.dials()
        d.phase = .cut
        d.ratePercentPerWeek = -0.5
        d.phaseStartDate = Fixture.day(13 * 7)
        let log = Fixture.steadyLog(days: 28, calories: 2200, startWeight: 184, lbPerDay: -0.1)
        let rec = report(log, d).recommendations.first { $0.rule == .longCut }
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec!.proposals.map(\.key), [.phase, .ratePercentPerWeek])
        XCTAssertEqual(rec!.proposals[0].newValue, .choice("maintain"))
        d.phaseStartDate = Fixture.day(10 * 7)
        XCTAssertNil(report(log, d).recommendations.first { $0.rule == .longCut })
    }

    func testBulkOvershoot() {
        var d = Fixture.dials()
        d.phase = .bulk
        d.bodyFatPercentManual = 19
        let rec = report([], d).recommendations.first { $0.rule == .bulkOvershoot }
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec!.proposals[0].newValue, .choice("cut"))
        d.bodyFatPercentManual = 17
        XCTAssertNil(report([], d).recommendations.first { $0.rule == .bulkOvershoot })
    }

    func testUndertrainedMuscleWhileBulking() {
        var d = Fixture.dials()
        d.phase = .leanBulk
        d.undertrainedWeeks = 2
        d.muscleUnlockWeeks = 2
        d.hardSetsTargetPerWeek = 10
        var sets: [LiftSetInput] = []
        for week in 0..<2 {
            for i in 1...12 { sets.append(LiftSetInput(date: Fixture.day(week * 7 + 2), exercise: "Bench Press", setIndex: i, weightLb: 200, reps: 8)) }
            for i in 1...4 { sets.append(LiftSetInput(date: Fixture.day(week * 7 + 3), exercise: "Leg Curl", setIndex: i, weightLb: 100, reps: 10)) }
        }
        let rec = report([], d, sets: sets).recommendations.first { $0.rule == .undertrainedMuscle }
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec!.headline, "Add sets for glutes", "glutes get half credit from leg curls, so they're the lowest")
        XCTAssertTrue(rec!.reason.contains("Hamstrings"))
        XCTAssertTrue(rec!.reason.contains("Leg Curl"))
        XCTAssertFalse(rec!.hasProposal)
    }

    func testProteinShort() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0)
        for i in 1...7 { log[i].proteinG = i <= 4 ? 120 : 200 }
        let rec = report(log, Fixture.dials()).recommendations.first { $0.rule == .proteinShort }
        XCTAssertNotNil(rec)
        XCTAssertTrue(rec!.reason.contains("3 of 7 days"))
        for i in 1...7 { log[i].proteinG = 200 }
        XCTAssertNil(report(log, Fixture.dials()).recommendations.first { $0.rule == .proteinShort })
    }

    func testStepsDrifting() {
        var log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0, steps: 10000)
        for i in 1...7 { log[i].steps = 6000 }
        let rec = report(log, Fixture.dials()).recommendations.first { $0.rule == .stepsDrifting }
        XCTAssertNotNil(rec)
        XCTAssertTrue(rec!.headline.contains("Steps dropped"))
        XCTAssertFalse(rec!.hasProposal)
        for i in 1...7 { log[i].steps = 9500 }
        XCTAssertNil(report(log, Fixture.dials()).recommendations.first { $0.rule == .stepsDrifting })
    }

    func testCheckInDue() {
        var d = Dials()
        d.coachCheckInWeekday = 3 // Tuesday
        XCTAssertTrue(Coach.isCheckInDue(lastCheckIn: nil, today: Fixture.today, dials: d, calendar: Fixture.calendar))
        XCTAssertTrue(Coach.isCheckInDue(lastCheckIn: Fixture.day(7), today: Fixture.today, dials: d, calendar: Fixture.calendar))
        XCTAssertFalse(Coach.isCheckInDue(lastCheckIn: Fixture.today, today: Fixture.today, dials: d, calendar: Fixture.calendar))
        d.coachCheckInWeekday = 1
        XCTAssertFalse(Coach.isCheckInDue(lastCheckIn: nil, today: Fixture.today, dials: d, calendar: Fixture.calendar))
    }

    func testRecommendationIsCodable() throws {
        var d = Fixture.dials()
        d.trendAlpha = 1.0
        let log = Fixture.steadyLog(days: 28, calories: 3000, startWeight: 184, lbPerDay: 0)
        let rec = report(log, d, previousMisses: 1).recommendations.first { $0.rule == .rateOffTarget }!
        let data = try Dials.jsonEncoder.encode(rec)
        let back = try Dials.jsonDecoder.decode(CoachRecommendation.self, from: data)
        XCTAssertEqual(back.headline, rec.headline)
        XCTAssertEqual(back.proposals, rec.proposals)
    }
}
