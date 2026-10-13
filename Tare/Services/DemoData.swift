import Foundation
import SwiftData
import UIKit
import TareEngine

/// A deterministic six-week lean bulk, close to the sample data in SCREENS.md.
/// Loaded with the `-TareDemoData` launch argument (UI tests) or from Data sources.
@MainActor
enum DemoData {
    static var requestedAtLaunch: Bool { CommandLine.arguments.contains("-TareDemoData") }

    static func seed(into model: AppModel) {
        var rng = SeededRandom(seed: 20261013)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func day(_ back: Int) -> Date { calendar.date(byAdding: .day, value: -back, to: today) ?? today }

        wipe(model)

        // Profile and plan
        var d = Dials()
        d.sex = .male
        d.birthDate = calendar.date(byAdding: .year, value: -30, to: today)
        d.heightCm = 180
        d.bodyFatSource = .manual
        d.bodyFatPercentManual = 14
        d.phase = .leanBulk
        d.phaseStartDate = day(41)
        d.ratePercentPerWeek = 0.30
        model.replaceDials(d, source: .onboarding, keepPhaseStart: false)
        // The log entries that mark the chart: the phase switch six weeks ago, a coach rate change three weeks ago.
        model.context.insert(DialChange(key: .phase, title: "Phase", oldValue: .choice(Phase.cut.rawValue), newValue: .choice(Phase.leanBulk.rawValue), source: .user, date: day(41)))
        model.context.insert(DialChange(key: .ratePercentPerWeek, title: "Rate", oldValue: .number(0.25), newValue: .number(0.30), source: .coach, date: day(21)))

        // Days: 60 back. Flat through the end of the cut, then a slow climb with noise.
        var days: [DayInput] = []
        var weight = 183.0
        for back in stride(from: 59, through: 0, by: -1) {
            let bulking = back <= 41
            weight += bulking ? 0.045 : -0.01
            let noise = rng.next(in: -0.6...0.6)
            let lifting = back % 2 == 1 || back == 0
            let protein = rng.next(in: 165...200).rounded()
            let fat = rng.next(in: 60...80).rounded()
            let calories = (bulking ? 3300.0 : 2500.0) + rng.next(in: -160...160).rounded()
            let carbs = max(0, ((calories - protein * 4 - fat * 9) / 4).rounded())
            var input = DayInput(
                date: day(back),
                weightLb: (weight + noise).rounded(toPlaces: 1),
                calories: calories,
                proteinG: protein,
                carbsG: carbs,
                fatG: fat,
                waterOz: rng.next(in: 70...110).rounded(),
                steps: Int(rng.next(in: 7200...11000)),
                activeEnergyKcal: rng.next(in: 500...900).rounded(),
                liftMinutes: lifting ? rng.next(in: 62...82).rounded() : nil,
                liftStyle: lifting ? "Hypertrophy" : nil,
                cardioSessions: back % 7 == 3 ? [CardioSession(type: "Walk", minutes: 30)] : [],
                foodLogComplete: !(back == 12 || back == 19)
            )
            if back == 0 {
                input.calories = 1840
                input.proteinG = 128
                input.carbsG = 212
                input.fatG = 41
                input.steps = 6210
                input.weightLb = 184.6
            }
            days.append(input)
        }
        model.upsertDays(days, synced: true)

        // Lift sets, eight weeks, four-day split with slow progression.
        var sets: [LiftSetInput] = []
        let split: [[(String, Double, Int)]] = [
            [("Bench Press (Barbell)", 225, 5), ("Overhead Press", 125, 6), ("Incline Dumbbell Press", 70, 10), ("Triceps Pushdown", 60, 12)],
            [("Back Squat", 295, 5), ("Leg Curl", 110, 10), ("Leg Press", 400, 10), ("Standing Calf Raise", 180, 12)],
            [("Barbell Row", 185, 8), ("Lat Pulldown", 160, 10), ("Bicep Curl (Dumbbell)", 35, 10), ("Face Pull", 50, 15)],
            [("Romanian Deadlift", 275, 6), ("Bulgarian Split Squat", 50, 10), ("Hip Thrust", 245, 10), ("Hammer Curl", 35, 10)],
        ]
        var session = 0
        for back in stride(from: 55, through: 0, by: -1) where back % 2 == 1 || back == 0 {
            let dayPlan = split[session % split.count]
            let weeksIn = Double(55 - back) / 7
            for (exercise, base, reps) in dayPlan {
                let load = base + (weeksIn * 2.5).rounded(.down) * (base > 150 ? 2 : 1)
                sets.append(LiftSetInput(date: day(back), exercise: exercise, setIndex: 0, setType: .warmup, weightLb: (load * 0.5).rounded(), reps: 8, source: "Hevy"))
                for i in 1...4 {
                    sets.append(LiftSetInput(date: day(back), exercise: exercise, setIndex: i, setType: .working, weightLb: load, reps: max(3, reps - (i == 4 ? 1 : 0)), rpe: 8, source: "Hevy"))
                }
            }
            session += 1
        }
        model.addLiftSets(sets, batchID: "demo")

        // Two placeholder progress photos so the compare strip has a pair.
        for (back, label) in [(41, "Sep 1"), (0, "Oct 13")] {
            let image = placeholderPhoto(label: label, tint: back == 0 ? UIColor(red: 0.14, green: 0.33, blue: 0.80, alpha: 1) : UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1))
            PhotoSaver.save(image: image, pose: .front, customName: nil, date: day(back), model: model)
        }

        // One missed check-in already on record, so this week's miss produces a recommendation.
        AppState.rateMisses = 1
        AppState.lastCheckIn = nil
        AppState.healthAuthorized = false
        model.reloadAll()
        model.runCoachNow()
    }

    static func wipe(_ model: AppModel) {
        let ctx = model.context
        try? ctx.delete(model: DayRecord.self)
        try? ctx.delete(model: LiftSet.self)
        try? ctx.delete(model: ExerciseMapEntry.self)
        try? ctx.delete(model: ProgressPhoto.self)
        try? ctx.delete(model: Recommendation.self)
        try? ctx.delete(model: ImportMappingRecord.self)
        try? ctx.delete(model: PresetRecord.self)
        try? ctx.delete(model: DialChange.self)
        try? ctx.save()
    }

    static func placeholderPhoto(label: String, tint: UIColor) -> UIImage {
        let size = CGSize(width: 600, height: 800)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [tint.withAlphaComponent(0.35).cgColor, tint.withAlphaComponent(0.9).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            // A simple silhouette.
            c.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            c.fillEllipse(in: CGRect(x: 250, y: 90, width: 100, height: 100))
            c.fill(CGRect(x: 215, y: 200, width: 170, height: 260))
            c.fill(CGRect(x: 230, y: 460, width: 60, height: 260))
            c.fill(CGRect(x: 310, y: 460, width: 60, height: 260))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40, weight: .bold), .foregroundColor: UIColor.white]
            (label as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: attrs)
        }
    }
}

/// Small linear congruential generator so demo data is the same on every run.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
