import Foundation

/// Ordinary least-squares line through (x, y) points.
public struct LinearFit: Equatable, Sendable {
    public let slope: Double
    public let intercept: Double
    public let count: Int

    public func value(at x: Double) -> Double { intercept + slope * x }

    /// Returns nil with fewer than two points or when every x is the same.
    public static func fit(_ points: [(x: Double, y: Double)]) -> LinearFit? {
        let n = Double(points.count)
        guard points.count >= 2 else { return nil }
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let meanX = sumX / n
        let meanY = sumY / n
        var sxx = 0.0
        var sxy = 0.0
        for p in points {
            let dx = p.x - meanX
            sxx += dx * dx
            sxy += dx * (p.y - meanY)
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        return LinearFit(slope: slope, intercept: meanY - slope * meanX, count: points.count)
    }
}

public extension Array where Element == Double {
    var mean: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
