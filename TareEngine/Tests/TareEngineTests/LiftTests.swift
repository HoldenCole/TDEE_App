import XCTest
@testable import TareEngine

final class LiftTests: XCTestCase {

    func testMuscleMapKeywords() {
        let map = MuscleMap()
        XCTAssertEqual(map.lookup("Bench Press (Barbell)")?.primary, .chest)
        XCTAssertEqual(map.lookup("Incline Dumbbell Press")?.primary, .chest)
        XCTAssertEqual(map.lookup("Back Squat")?.primary, .quads)
        XCTAssertEqual(map.lookup("Romanian Deadlift")?.primary, .hamstrings)
        XCTAssertEqual(map.lookup("Deadlift")?.primary, .back)
        XCTAssertEqual(map.lookup("Lying Leg Curl")?.primary, .hamstrings)
        XCTAssertEqual(map.lookup("Hammer Curl")?.primary, .forearms)
        XCTAssertEqual(map.lookup("Bicep Curl (Dumbbell)")?.primary, .biceps)
        XCTAssertEqual(map.lookup("Lat Pulldown")?.primary, .back)
        XCTAssertEqual(map.lookup("Seated Cable Row")?.primary, .back)
        XCTAssertEqual(map.lookup("Overhead Press")?.primary, .shoulders)
        XCTAssertEqual(map.lookup("Triceps Pushdown")?.primary, .triceps)
        XCTAssertEqual(map.lookup("Standing Calf Raise")?.primary, .calves)
        XCTAssertEqual(map.lookup("Hip Thrust")?.primary, .glutes)
        XCTAssertNil(map.lookup("Mystery Machine"))
    }

    func testUserTagOverridesBuiltIn() {
        var map = MuscleMap()
        map.tag("Deadlift", as: ExerciseMuscles(primary: .hamstrings, secondary: [.back]))
        XCTAssertEqual(map.lookup("deadlift")?.primary, .hamstrings)
        XCTAssertEqual(map.unknownExercises(in: [LiftSetInput(date: Fixture.day(0), exercise: "Mystery", setIndex: 1, weightLb: 100, reps: 5), LiftSetInput(date: Fixture.day(0), exercise: "Deadlift", setIndex: 1, weightLb: 100, reps: 5)]), ["Mystery"])
    }

    func testEpley() {
        XCTAssertEqual(LiftAnalytics.epley(weightLb: 225, reps: 5), 225 * (1 + 5.0 / 30), accuracy: 1e-9)
    }

    func testWeeklyHardSetsCreditPrimaryAndSecondary() {
        var sets: [LiftSetInput] = []
        for i in 1...3 {
            sets.append(LiftSetInput(date: Fixture.day(2), exercise: "Bench Press", setIndex: i, setType: .working, weightLb: 200, reps: 8))
        }
        sets.append(LiftSetInput(date: Fixture.day(2), exercise: "Bench Press", setIndex: 0, setType: .warmup, weightLb: 95, reps: 10))
        sets.append(LiftSetInput(date: Fixture.day(9), exercise: "Back Squat", setIndex: 1, setType: .working, weightLb: 300, reps: 5))
        let weeks = LiftAnalytics.weeklyHardSets(sets: sets, map: MuscleMap(), weeks: 2, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(weeks.count, 2)
        let thisWeek = weeks[1].sets
        XCTAssertEqual(thisWeek[.chest], 3)
        XCTAssertEqual(thisWeek[.triceps], 1.5)
        XCTAssertEqual(thisWeek[.shoulders], 1.5)
        XCTAssertNil(thisWeek[.quads])
        XCTAssertEqual(weeks[0].sets[.quads], 1)
        XCTAssertEqual(LiftAnalytics.averageWeeklySets(weeks)[.chest], 1.5)
    }

    func testStrengthUsesBestSetOfTenOrFewerRepsPerSession() {
        let sets = [
            LiftSetInput(date: Fixture.day(7), exercise: "Bench Press", setIndex: 1, weightLb: 200, reps: 8),
            LiftSetInput(date: Fixture.day(7), exercise: "Bench Press", setIndex: 2, weightLb: 185, reps: 12),
            LiftSetInput(date: Fixture.day(7), exercise: "Bench Press", setIndex: 3, weightLb: 210, reps: 5),
            LiftSetInput(date: Fixture.day(0), exercise: "Bench Press", setIndex: 1, weightLb: 215, reps: 5),
        ]
        let strength = LiftAnalytics.strength(sets: sets, calendar: Fixture.calendar)
        XCTAssertEqual(strength.count, 1)
        let bench = strength[0]
        XCTAssertEqual(bench.sessions.count, 2)
        let best = max(LiftAnalytics.epley(weightLb: 200, reps: 8), LiftAnalytics.epley(weightLb: 210, reps: 5))
        XCTAssertEqual(bench.sessions[0].e1RM, best, accuracy: 1e-9, "the 12-rep set is ignored; the best e1RM wins, not the heaviest bar")
        XCTAssertEqual(bench.sessions[0].bestSetWeightLb, 200)
        XCTAssertEqual(bench.latest!, LiftAnalytics.epley(weightLb: 215, reps: 5), accuracy: 1e-9)
        XCTAssertEqual(bench.change(since: Fixture.day(30))!, LiftAnalytics.epley(weightLb: 215, reps: 5) - best, accuracy: 1e-9)
        XCTAssertEqual(LiftAnalytics.relativeStrength(e1RM: 250, trendWeightLb: 200)!, 1.25)
    }

    func testUnlockThresholds() {
        var d = Dials()
        d.muscleUnlockWeeks = 2
        d.exerciseUnlockSessions = 2
        let sets = [
            LiftSetInput(date: Fixture.day(1), exercise: "Back Squat", setIndex: 1, weightLb: 300, reps: 5),
            LiftSetInput(date: Fixture.day(8), exercise: "Back Squat", setIndex: 1, weightLb: 295, reps: 5),
            LiftSetInput(date: Fixture.day(1), exercise: "Bench Press", setIndex: 1, weightLb: 200, reps: 5),
        ]
        let unlockedMuscles = LiftAnalytics.unlockedMuscles(sets: sets, map: MuscleMap(), dials: d, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertTrue(unlockedMuscles.contains(.quads))
        XCTAssertFalse(unlockedMuscles.contains(.chest))
        let unlockedEx = LiftAnalytics.unlockedExercises(LiftAnalytics.strength(sets: sets, calendar: Fixture.calendar), dials: d)
        XCTAssertEqual(unlockedEx.map(\.exercise), ["Back Squat"])
    }

    func testStrengthChangeByMuscleAndExercisesForMuscle() {
        let sets = [
            LiftSetInput(date: Fixture.day(50), exercise: "Back Squat", setIndex: 1, weightLb: 300, reps: 5),
            LiftSetInput(date: Fixture.day(1), exercise: "Back Squat", setIndex: 1, weightLb: 330, reps: 5),
            LiftSetInput(date: Fixture.day(1), exercise: "Leg Press", setIndex: 1, weightLb: 500, reps: 10),
        ]
        let strength = LiftAnalytics.strength(sets: sets, calendar: Fixture.calendar)
        let change = LiftAnalytics.strengthChangeByMuscle(strength: strength, map: MuscleMap(), weeks: 8, today: Fixture.today, calendar: Fixture.calendar)
        XCTAssertEqual(change[.quads]!, 10, accuracy: 1e-9)
        XCTAssertEqual(LiftAnalytics.exercises(for: .quads, in: sets, map: MuscleMap()), ["Back Squat", "Leg Press"])
    }
}
