import Foundation
@testable import TareEngine

/// A fixed calendar and "today" so every test is deterministic.
enum Fixture {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }()

    /// Tuesday, 13 October 2026.
    static let today: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = 13
        comps.hour = 9
        return calendar.date(from: comps)!
    }()

    static func day(_ back: Int) -> Date {
        calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: today))!
    }

    /// Dials with a complete profile so every formula runs.
    static func dials() -> Dials {
        var d = Dials()
        d.sex = .male
        d.heightCm = 180
        d.birthDate = calendar.date(byAdding: .year, value: -30, to: calendar.startOfDay(for: today))
        d.bodyFatSource = .manual
        d.bodyFatPercentManual = 15
        return d
    }

    /// A steady log: `days` days back from yesterday, constant intake and a linear weight line.
    static func steadyLog(days: Int, calories: Double, startWeight: Double, lbPerDay: Double, steps: Int = 8000, liftEvery: Int = 2, liftMinutes: Double = 60) -> [DayInput] {
        (0..<days).map { back in
            let lifting = liftEvery > 0 && back % liftEvery == 1
            return DayInput(
                date: day(back),
                weightLb: startWeight - lbPerDay * Double(back),
                calories: calories,
                proteinG: 190,
                carbsG: 400,
                fatG: 70,
                steps: steps,
                liftMinutes: lifting ? liftMinutes : nil,
                liftStyle: lifting ? "Hypertrophy" : nil
            )
        }
    }
}
