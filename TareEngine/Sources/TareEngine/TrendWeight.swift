import Foundation

public struct TrendPoint: Equatable, Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let weightLb: Double
    public let trendLb: Double
    public let isOutlier: Bool
}

/// Exponential moving average of weigh-ins with an outlier filter.
public enum TrendWeight {

    /// - Parameters:
    ///   - weighIns: any order; sorted by date inside.
    ///   - alpha: smoothing, 0.05–0.25.
    ///   - outlierThresholdLb: weigh-ins further than this from the trend are skipped.
    ///     Three skipped in a row are accepted so a real step change still gets through.
    public static func series(weighIns: [(date: Date, weightLb: Double)], alpha: Double, outlierThresholdLb: Double?) -> [TrendPoint] {
        let sorted = weighIns.sorted { $0.date < $1.date }
        guard let first = sorted.first else { return [] }
        var trend = first.weightLb
        var points: [TrendPoint] = [TrendPoint(date: first.date, weightLb: first.weightLb, trendLb: trend, isOutlier: false)]
        var consecutiveOutliers = 0
        let a = min(max(alpha, 0.01), 1.0)

        for w in sorted.dropFirst() {
            let delta = w.weightLb - trend
            if let threshold = outlierThresholdLb, abs(delta) > threshold, consecutiveOutliers < 2 {
                consecutiveOutliers += 1
                points.append(TrendPoint(date: w.date, weightLb: w.weightLb, trendLb: trend, isOutlier: true))
                continue
            }
            consecutiveOutliers = 0
            trend += a * delta
            points.append(TrendPoint(date: w.date, weightLb: w.weightLb, trendLb: trend, isOutlier: false))
        }
        return points
    }

    public static func series(log: [DayInput], dials: Dials) -> [TrendPoint] {
        let weighIns = log.compactMap { day -> (date: Date, weightLb: Double)? in
            guard let w = day.weightLb else { return nil }
            return (day.date, w)
        }
        return series(weighIns: weighIns, alpha: dials.trendAlpha, outlierThresholdLb: dials.outlierThresholdLb)
    }
}
