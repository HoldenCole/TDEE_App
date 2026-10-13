import Foundation

public struct BMRInputs: Equatable, Sendable {
    public var weightKg: Double
    public var heightCm: Double?
    public var ageYears: Double?
    public var sex: Sex
    public var leanMassKg: Double?

    public init(weightKg: Double, heightCm: Double?, ageYears: Double?, sex: Sex, leanMassKg: Double?) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.sex = sex
        self.leanMassKg = leanMassKg
    }
}

public struct BMRResult: Equatable, Sendable {
    /// Final BMR after the mode, adjustment and any measured override.
    public let value: Double
    /// Every formula the inputs allowed, before adjustment.
    public let byFormula: [BMRFormula: Double]
    /// The formulas that fed `value`.
    public let used: [BMRFormula]
    public let isMeasured: Bool
    /// True when no formula could run and a rough fallback was used.
    public let isFallback: Bool

    public var sourceDescription: String {
        if isMeasured { return "Measured RMR" }
        if isFallback { return "Estimate, add height and age" }
        let names = used.map { $0.shortName }
        if names.count == 1 { return names[0] }
        return names.joined(separator: " + ") + " avg"
    }
}

public extension BMRFormula {
    var shortName: String {
        switch self {
        case .average: return "Average"
        case .mifflin: return "Mifflin"
        case .katchMcArdle: return "Katch"
        case .cunningham: return "Cunningham"
        case .harrisBenedict: return "Harris"
        case .weighted: return "Weighted"
        }
    }
}

public enum BMRCalculator {

    public static func mifflin(weightKg W: Double, heightCm H: Double, age A: Double, sex: Sex) -> Double {
        10 * W + 6.25 * H - 5 * A + (sex == .male ? 5 : -161)
    }

    public static func katchMcArdle(leanMassKg: Double) -> Double {
        370 + 21.6 * leanMassKg
    }

    public static func cunningham(leanMassKg: Double) -> Double {
        500 + 22 * leanMassKg
    }

    public static func harrisBenedict(weightKg W: Double, heightCm H: Double, age A: Double, sex: Sex) -> Double {
        switch sex {
        case .male: return 88.4 + 13.4 * W + 4.8 * H - 5.7 * A
        case .female: return 447.6 + 9.2 * W + 3.1 * H - 4.3 * A
        }
    }

    /// Every formula the inputs allow.
    public static func available(_ inputs: BMRInputs) -> [BMRFormula: Double] {
        var out: [BMRFormula: Double] = [:]
        if let h = inputs.heightCm, let a = inputs.ageYears {
            out[.mifflin] = mifflin(weightKg: inputs.weightKg, heightCm: h, age: a, sex: inputs.sex)
            out[.harrisBenedict] = harrisBenedict(weightKg: inputs.weightKg, heightCm: h, age: a, sex: inputs.sex)
        }
        if let lbm = inputs.leanMassKg, lbm > 0 {
            out[.katchMcArdle] = katchMcArdle(leanMassKg: lbm)
            out[.cunningham] = cunningham(leanMassKg: lbm)
        }
        return out
    }

    public static func compute(_ inputs: BMRInputs, dials: Dials) -> BMRResult {
        let formulas = available(inputs)

        if let measured = dials.measuredRMR, measured > 0 {
            return BMRResult(value: measured, byFormula: formulas, used: [], isMeasured: true, isFallback: false)
        }

        let adjustment = 1 + dials.bmrAdjustmentPercent / 100
        let order: [BMRFormula] = [.mifflin, .katchMcArdle, .cunningham, .harrisBenedict]

        func averageOfAvailable() -> (Double, [BMRFormula])? {
            let used = order.filter { formulas[$0] != nil }
            guard !used.isEmpty else { return nil }
            let total = used.reduce(0) { $0 + (formulas[$1] ?? 0) }
            return (total / Double(used.count), used)
        }

        var picked: (Double, [BMRFormula])?
        switch dials.bmrFormula {
        case .average:
            picked = averageOfAvailable()
        case .mifflin, .katchMcArdle, .cunningham, .harrisBenedict:
            if let v = formulas[dials.bmrFormula] {
                picked = (v, [dials.bmrFormula])
            } else {
                picked = averageOfAvailable()
            }
        case .weighted:
            let weights: [(BMRFormula, Double)] = [
                (.mifflin, dials.bmrWeights.mifflin),
                (.katchMcArdle, dials.bmrWeights.katchMcArdle),
                (.cunningham, dials.bmrWeights.cunningham),
                (.harrisBenedict, dials.bmrWeights.harrisBenedict),
            ].filter { formulas[$0.0] != nil && $0.1 > 0 }
            let totalWeight = weights.reduce(0) { $0 + $1.1 }
            if totalWeight > 0 {
                let value = weights.reduce(0) { $0 + $1.1 * (formulas[$1.0] ?? 0) } / totalWeight
                picked = (value, weights.map(\.0))
            } else {
                picked = averageOfAvailable()
            }
        }

        if let (value, used) = picked {
            return BMRResult(value: value * adjustment, byFormula: formulas, used: used, isMeasured: false, isFallback: false)
        }
        // Nothing computable: a rough 22 kcal per kg keeps the app usable until height and age arrive.
        return BMRResult(value: inputs.weightKg * 22 * adjustment, byFormula: formulas, used: [], isMeasured: false, isFallback: true)
    }
}
