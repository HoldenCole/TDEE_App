import Foundation

public struct ObservedTDEEResult: Equatable, Sendable {
    /// nil until there is enough data.
    public let value: Double?
    public let meanIntake: Double?
    public let slopeLbPerDay: Double?
    public let daysWithCalories: Int
    public let daysWithWeight: Int
    public let windowDays: Int
    public let requiredDays: Int
    public let windowStart: Date
    public let windowEnd: Date

    public var isAvailable: Bool { value != nil }

    /// kcal/day the weight change accounts for (negative while losing).
    public var weightChangeKcal: Double? {
        guard let s = slopeLbPerDay else { return nil }
        return s * kcalPerLb
    }
    let kcalPerLb: Double
}

/// `TDEE_observed = mean(kcal eaten) − slope_lb_per_day × kcal_per_lb` over the trust window.
///
/// The calorie window is the N days ending yesterday (today's food is still being logged);
/// the weigh-in window is the N days ending today, so this morning's weight counts.
public enum ObservedTDEE {

    public static func compute(log: [DayInput], today: Date, dials: Dials, calendar: Calendar) -> ObservedTDEEResult {
        let n = max(1, dials.trustWindowDays)
        let required = max(2, dials.minDaysBeforeTrust)
        let todayStart = calendar.startOfDay(for: today)
        let windowStart = calendar.date(byAdding: .day, value: -n, to: todayStart) ?? todayStart

        var intakes: [Double] = []
        var weights: [(x: Double, y: Double)] = []

        for day in log {
            let idx = calendar.days(from: day.date, to: today)
            if idx >= 1 && idx <= n, day.countsForIntake(policy: dials.incompleteFoodDays), let kcal = day.calories {
                intakes.append(kcal)
            }
            if idx >= 0 && idx < n, let w = day.weightLb {
                weights.append((x: Double(-idx), y: w))
            }
        }

        let fit = LinearFit.fit(weights)
        let meanIntake = intakes.mean
        var value: Double?
        if intakes.count >= required, weights.count >= required, let fit, let mean = meanIntake {
            value = mean - fit.slope * dials.kcalPerLb
        }
        return ObservedTDEEResult(value: value, meanIntake: meanIntake, slopeLbPerDay: fit?.slope, daysWithCalories: intakes.count, daysWithWeight: weights.count, windowDays: n, requiredDays: required, windowStart: windowStart, windowEnd: todayStart, kcalPerLb: dials.kcalPerLb)
    }
}
