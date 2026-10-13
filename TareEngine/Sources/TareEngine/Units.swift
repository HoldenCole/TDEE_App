import Foundation

public enum Units {
    public static let kgPerLb = 0.45359237
    public static let cmPerInch = 2.54

    public static func kg(fromLb lb: Double) -> Double { lb * kgPerLb }
    public static func lb(fromKg kg: Double) -> Double { kg / kgPerLb }
    public static func cm(fromInches inches: Double) -> Double { inches * cmPerInch }
    public static func inches(fromCm cm: Double) -> Double { cm / cmPerInch }

    /// Rounds to the nearest multiple of `step` (1 or less returns the value rounded to a whole number).
    public static func round(_ value: Double, toNearest step: Int) -> Double {
        guard step > 1 else { return value.rounded() }
        return (value / Double(step)).rounded() * Double(step)
    }
}

public extension Calendar {
    /// Whole days from `from` to `to`, by calendar day (ignores time of day).
    func days(from: Date, to: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: from), to: startOfDay(for: to)).day ?? 0
    }
}
