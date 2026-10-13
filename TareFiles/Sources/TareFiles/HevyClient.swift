import Foundation
import TareEngine
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A GET-only HTTP transport so tests can inject canned responses.
public protocol HTTPTransport: Sendable {
    /// Returns the body and HTTP status code.
    func get(_ url: URL, headers: [String: String]) async throws -> (Data, Int)
}

/// `URLSession`-backed transport.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, headers: [String: String]) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}

public enum HevyError: Error, Equatable, LocalizedError, Sendable {
    /// 401: the API key was rejected.
    case invalidAPIKey
    /// 403: the Hevy API needs a Hevy Pro subscription.
    case proRequired
    /// 429: too many requests.
    case rateLimited
    /// Any other non-2xx status.
    case httpStatus(Int)
    /// The response body was not what the client expected.
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Hevy rejected the API key. Check it in Hevy's settings under Developer."
        case .proRequired: return "The Hevy API needs a Hevy Pro subscription."
        case .rateLimited: return "Hevy is rate limiting requests. Try again in a minute."
        case .httpStatus(let code): return "Hevy returned HTTP \(code)."
        case .decoding(let detail): return "Could not read Hevy's response: \(detail)"
        }
    }
}

public struct HevyWorkoutSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date?
    public var durationMinutes: Double?

    public init(id: String, title: String, start: Date, end: Date? = nil, durationMinutes: Double? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.durationMinutes = durationMinutes
    }
}

public struct HevyFetchResult: Equatable, Sendable {
    public var sets: [LiftSetInput]
    public var workouts: [HevyWorkoutSummary]
    /// Exercise titles seen that were not in the caller's `knownExercises`, in first-seen order.
    public var unknownExercises: [String]
    /// Exercise title → Hevy exercise template id, for `exerciseTemplate(id:)` lookups.
    public var templateIDs: [String: String]

    public init(sets: [LiftSetInput] = [], workouts: [HevyWorkoutSummary] = [], unknownExercises: [String] = [], templateIDs: [String: String] = [:]) {
        self.sets = sets
        self.workouts = workouts
        self.unknownExercises = unknownExercises
        self.templateIDs = templateIDs
    }
}

public struct HevyExerciseTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var primaryMuscleGroup: String?
    public var secondaryMuscleGroups: [String]

    public init(id: String, title: String, primaryMuscleGroup: String? = nil, secondaryMuscleGroups: [String] = []) {
        self.id = id
        self.title = title
        self.primaryMuscleGroup = primaryMuscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
    }

    public var primaryMuscle: Muscle? { primaryMuscleGroup.flatMap(HevyClient.muscle(fromHevyGroup:)) }
    public var secondaryMuscles: [Muscle] { secondaryMuscleGroups.compactMap(HevyClient.muscle(fromHevyGroup:)) }
}

/// Client for Hevy's public API (https://api.hevyapp.com/v1).
public final class HevyClient: Sendable {
    public static let sourceName = "Hevy"
    public static let defaultBaseURL = URL(string: "https://api.hevyapp.com/v1")!

    private let apiKey: String
    private let transport: HTTPTransport
    private let baseURL: URL

    public init(apiKey: String, transport: HTTPTransport = URLSessionTransport(), baseURL: URL = HevyClient.defaultBaseURL) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = transport
        self.baseURL = baseURL
    }

    // MARK: Workouts

    /// Pages through `/workouts` newest first, stopping at the last page or once a whole page
    /// is older than `since`. Weights come back in pounds.
    public func fetchWorkouts(since: Date? = nil, pageSize: Int = 10, knownExercises: Set<String> = []) async throws -> HevyFetchResult {
        var result = HevyFetchResult()
        var seenUnknown: Set<String> = []
        var page = 1
        let size = max(1, min(pageSize, 10))

        while true {
            let url = baseURL.appendingPathComponent("workouts").appendingQuery(["page": String(page), "pageSize": String(size)])
            let data = try await getData(url)
            let payload: WorkoutsPage
            do {
                payload = try HevyClient.decoder.decode(WorkoutsPage.self, from: data)
            } catch {
                throw HevyError.decoding("workouts page \(page): \(error)")
            }

            var allOlder = !payload.workouts.isEmpty
            for workout in payload.workouts {
                guard let start = workout.startDate else {
                    throw HevyError.decoding("workout \(workout.id) has an unreadable start_time '\(workout.start_time ?? "")'.")
                }
                if let since, start < since { continue }
                allOlder = false

                let end = workout.end_time.flatMap { DateParsing.date($0) }
                let duration = end.map { $0.timeIntervalSince(start) / 60 }
                result.workouts.append(HevyWorkoutSummary(id: workout.id, title: workout.title ?? "", start: start, end: end, durationMinutes: duration))

                for exercise in workout.exercises ?? [] {
                    let title = exercise.title ?? "Unknown exercise"
                    if let templateID = exercise.exercise_template_id { result.templateIDs[title] = templateID }
                    if !knownExercises.contains(title), !seenUnknown.contains(title) {
                        seenUnknown.insert(title)
                        result.unknownExercises.append(title)
                    }
                    var running = 0
                    for set in exercise.sets ?? [] {
                        defer { running += 1 }
                        guard let reps = set.reps else { continue } // duration or distance sets
                        let weightLb = set.weight_kg.map(Units.lb(fromKg:)) ?? 0
                        result.sets.append(LiftSetInput(
                            date: start,
                            exercise: title,
                            setIndex: set.index ?? running,
                            setType: HevyClient.setType(set.type),
                            weightLb: weightLb,
                            reps: reps,
                            rpe: set.rpe,
                            source: HevyClient.sourceName))
                    }
                }
            }

            if allOlder && since != nil { break }
            if page >= payload.page_count || payload.workouts.isEmpty { break }
            page += 1
        }
        return result
    }

    // MARK: Exercise templates

    /// `GET /exercise_templates/{id}`.
    public func exerciseTemplate(id: String) async throws -> HevyExerciseTemplate {
        let url = baseURL.appendingPathComponent("exercise_templates").appendingPathComponent(id)
        let data = try await getData(url)
        do {
            let t = try HevyClient.decoder.decode(TemplateResponse.self, from: data)
            return HevyExerciseTemplate(id: t.id, title: t.title ?? "", primaryMuscleGroup: t.primary_muscle_group, secondaryMuscleGroups: t.secondary_muscle_groups ?? [])
        } catch {
            throw HevyError.decoding("exercise template \(id): \(error)")
        }
    }

    /// Maps Hevy's muscle group names onto Tare's `Muscle`. Returns nil for cardio, full_body,
    /// neck, other and anything unrecognized.
    public static func muscle(fromHevyGroup group: String) -> Muscle? {
        switch group.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_") {
        case "chest": return .chest
        case "upper_back", "lats", "lower_back", "traps", "back": return .back
        case "shoulders", "delts": return .shoulders
        case "biceps": return .biceps
        case "triceps": return .triceps
        case "forearms": return .forearms
        case "abdominals", "abs", "core": return .abs
        case "quadriceps", "quads": return .quads
        case "hamstrings": return .hamstrings
        case "glutes": return .glutes
        case "calves": return .calves
        default: return nil
        }
    }

    /// "normal" → working, "warmup" → warmup, "dropset" → drop, "failure" → failure.
    public static func setType(_ raw: String?) -> SetType {
        ImportParser.setType(raw)
    }

    // MARK: Transport

    private func getData(_ url: URL) async throws -> Data {
        let headers = ["api-key": apiKey, "accept": "application/json"]
        let (data, status) = try await transport.get(url, headers: headers)
        switch status {
        case 200...299: return data
        case 401: throw HevyError.invalidAPIKey
        case 403: throw HevyError.proRequired
        case 429: throw HevyError.rateLimited
        default: throw HevyError.httpStatus(status)
        }
    }

    private static let decoder = JSONDecoder()

    // MARK: Wire types

    struct WorkoutsPage: Decodable {
        var page: Int?
        var page_count: Int
        var workouts: [Workout]
    }

    struct Workout: Decodable {
        var id: String
        var title: String?
        var start_time: String?
        var end_time: String?
        var exercises: [Exercise]?

        var startDate: Date? { start_time.flatMap { DateParsing.date($0) } }
    }

    struct Exercise: Decodable {
        var index: Int?
        var title: String?
        var exercise_template_id: String?
        var sets: [WorkoutSet]?
    }

    struct WorkoutSet: Decodable {
        var index: Int?
        var type: String?
        var weight_kg: Double?
        var reps: Int?
        var rpe: Double?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            index = try c.decodeIfPresent(Int.self, forKey: .index)
            type = try c.decodeIfPresent(String.self, forKey: .type)
            weight_kg = try c.decodeIfPresent(Double.self, forKey: .weight_kg)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .reps) { reps = i }
            else if let d = try? c.decodeIfPresent(Double.self, forKey: .reps) { reps = Int(d.rounded()) }
            else { reps = nil }
            rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        }

        enum CodingKeys: String, CodingKey { case index, type, weight_kg, reps, rpe }
    }

    struct TemplateResponse: Decodable {
        var id: String
        var title: String?
        var primary_muscle_group: String?
        var secondary_muscle_groups: [String]?
    }
}

extension URL {
    func appendingQuery(_ items: [String: String]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var query = components.queryItems ?? []
        for (k, v) in items.sorted(by: { $0.key < $1.key }) { query.append(URLQueryItem(name: k, value: v)) }
        components.queryItems = query
        return components.url ?? self
    }
}
