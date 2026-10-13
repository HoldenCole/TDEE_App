import XCTest
import TareEngine
@testable import TareFiles

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    var responses: [String: (Data, Int)] = [:]
    var requests: [(URL, [String: String])] = []
    let lock = NSLock()

    func get(_ url: URL, headers: [String: String]) async throws -> (Data, Int) {
        lock.lock(); defer { lock.unlock() }
        requests.append((url, headers))
        let key = url.absoluteString
        if let r = responses[key] { return r }
        if let r = responses.first(where: { key.hasSuffix($0.key) })?.value { return r }
        return (Data(), 404)
    }
}

final class HevyClientTests: XCTestCase {

    static let page1 = """
    {"page": 1, "page_count": 2, "workouts": [
      {"id": "w2", "title": "Pull", "start_time": "2026-10-14T06:00:00+00:00", "end_time": "2026-10-14T07:00:00+00:00",
       "exercises": [
         {"index": 0, "title": "Deadlift (Barbell)", "exercise_template_id": "t-dead",
          "sets": [{"index": 0, "type": "warmup", "weight_kg": 60, "reps": 5, "rpe": null},
                   {"index": 1, "type": "normal", "weight_kg": 140, "reps": 5, "rpe": 9}]},
         {"index": 1, "title": "Treadmill", "exercise_template_id": "t-tread",
          "sets": [{"index": 0, "type": "normal", "duration_seconds": 600, "distance_meters": 1500}]}
       ]},
      {"id": "w1", "title": "Push", "start_time": "2026-10-13T07:15:00+00:00", "end_time": "2026-10-13T08:20:00+00:00",
       "exercises": [
         {"index": 0, "title": "Bench Press (Barbell)", "exercise_template_id": "t-bench",
          "sets": [{"index": 0, "type": "normal", "weight_kg": 100, "reps": 5, "rpe": 8},
                   {"index": 1, "type": "dropset", "weight_kg": 80, "reps": 8},
                   {"index": 2, "type": "failure", "weight_kg": 80, "reps": 6, "rpe": 10}]}
       ]}
    ]}
    """
    static let page2 = """
    {"page": 2, "page_count": 2, "workouts": [
      {"id": "w0", "title": "Legs", "start_time": "2026-10-01T07:00:00+00:00", "end_time": null,
       "exercises": [
         {"index": 0, "title": "Squat (Barbell)", "exercise_template_id": "t-squat",
          "sets": [{"index": 0, "type": "normal", "weight_kg": 120, "reps": 5}]}
       ]}
    ]}
    """

    func makeClient(status: Int = 200) -> (HevyClient, FakeTransport) {
        let t = FakeTransport()
        t.responses["/workouts?page=1&pageSize=10"] = (Data(Self.page1.utf8), status)
        t.responses["/workouts?page=2&pageSize=10"] = (Data(Self.page2.utf8), status)
        t.responses["/exercise_templates/t-bench"] = (Data("""
        {"id": "t-bench", "title": "Bench Press (Barbell)", "type": "weight_reps", "primary_muscle_group": "chest", "secondary_muscle_groups": ["triceps", "shoulders"], "is_custom": false}
        """.utf8), status)
        return (HevyClient(apiKey: "  key-123 ", transport: t), t)
    }

    func testFetchesTwoPages() async throws {
        let (client, transport) = makeClient()
        let result = try await client.fetchWorkouts(since: nil, knownExercises: ["Treadmill"])

        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[0].0.absoluteString, "https://api.hevyapp.com/v1/workouts?page=1&pageSize=10")
        XCTAssertEqual(transport.requests[1].0.absoluteString, "https://api.hevyapp.com/v1/workouts?page=2&pageSize=10")
        XCTAssertEqual(transport.requests[0].1["api-key"], "key-123")
        XCTAssertEqual(transport.requests[0].1["accept"], "application/json")

        XCTAssertEqual(result.workouts.map(\.id), ["w2", "w1", "w0"])
        XCTAssertEqual(result.workouts[0].durationMinutes, 60)
        XCTAssertNil(result.workouts[2].end)
        XCTAssertEqual(result.workouts[1].start.timeIntervalSince1970, 1791875700)

        XCTAssertEqual(result.sets.count, 6)
        XCTAssertEqual(result.sets.map(\.exercise), ["Deadlift (Barbell)", "Deadlift (Barbell)", "Bench Press (Barbell)", "Bench Press (Barbell)", "Bench Press (Barbell)", "Squat (Barbell)"])
        XCTAssertEqual(result.sets.map(\.setType), [.warmup, .working, .working, .drop, .failure, .working])
        XCTAssertEqual(result.sets[2].weightLb, Units.lb(fromKg: 100), accuracy: 0.0001)
        XCTAssertEqual(result.sets[1].rpe, 9)
        XCTAssertNil(result.sets[0].rpe)
        XCTAssertEqual(result.sets.map(\.setIndex), [0, 1, 0, 1, 2, 0])
        XCTAssertTrue(result.sets.allSatisfy { $0.source == "Hevy" })
        XCTAssertEqual(result.unknownExercises, ["Deadlift (Barbell)", "Bench Press (Barbell)", "Squat (Barbell)"])
        XCTAssertEqual(result.templateIDs["Bench Press (Barbell)"], "t-bench")
    }

    func testStopsWhenPageIsOlderThanSince() async throws {
        let (client, transport) = makeClient()
        let since = DateParsing.date("2026-10-13T00:00:00Z")!
        let result = try await client.fetchWorkouts(since: since)
        XCTAssertEqual(transport.requests.count, 2) // page 2 is fetched, found all older, and the loop stops
        XCTAssertEqual(result.workouts.map(\.id), ["w2", "w1"])
        XCTAssertEqual(result.sets.count, 5)

        let later = DateParsing.date("2026-10-14T00:00:00Z")!
        let (client2, transport2) = makeClient()
        let r2 = try await client2.fetchWorkouts(since: later)
        XCTAssertEqual(r2.workouts.map(\.id), ["w2"])
        XCTAssertEqual(transport2.requests.count, 2)
    }

    func testExerciseTemplateAndMuscleMapping() async throws {
        let (client, _) = makeClient()
        let t = try await client.exerciseTemplate(id: "t-bench")
        XCTAssertEqual(t, HevyExerciseTemplate(id: "t-bench", title: "Bench Press (Barbell)", primaryMuscleGroup: "chest", secondaryMuscleGroups: ["triceps", "shoulders"]))
        XCTAssertEqual(t.primaryMuscle, .chest)
        XCTAssertEqual(t.secondaryMuscles, [.triceps, .shoulders])

        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "upper_back"), .back)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "lats"), .back)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "lower_back"), .back)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "traps"), .back)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "abdominals"), .abs)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "quadriceps"), .quads)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "Hamstrings"), .hamstrings)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "glutes"), .glutes)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "calves"), .calves)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "forearms"), .forearms)
        XCTAssertEqual(HevyClient.muscle(fromHevyGroup: "biceps"), .biceps)
        XCTAssertNil(HevyClient.muscle(fromHevyGroup: "cardio"))
        XCTAssertNil(HevyClient.muscle(fromHevyGroup: "full_body"))
        XCTAssertNil(HevyClient.muscle(fromHevyGroup: "other"))
        XCTAssertNil(HevyClient.muscle(fromHevyGroup: "neck"))
    }

    func testErrors() async {
        for (status, expected) in [(401, HevyError.invalidAPIKey), (403, .proRequired), (429, .rateLimited), (500, .httpStatus(500))] {
            let (client, _) = makeClient(status: status)
            do {
                _ = try await client.fetchWorkouts()
                XCTFail("expected error for \(status)")
            } catch let e as HevyError {
                XCTAssertEqual(e, expected)
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
        let t = FakeTransport()
        t.responses["/workouts?page=1&pageSize=10"] = (Data("{\"nope\": true}".utf8), 200)
        do {
            _ = try await HevyClient(apiKey: "k", transport: t).fetchWorkouts()
            XCTFail("expected decoding error")
        } catch let e as HevyError {
            if case .decoding = e {} else { XCTFail("wrong error \(e)") }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
