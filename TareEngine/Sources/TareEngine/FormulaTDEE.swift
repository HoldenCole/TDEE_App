import Foundation

/// A summary of the user's typical activity over the trust window, in raw units so
/// the MET and cost dials apply at compute time.
public struct ActivityProfile: Equatable, Sendable {
    public var stepsPerDay: Double
    public var liftSessionMinutes: Double
    public var liftStyle: String?
    public var liftDaysPerWeek: Double
    /// Average minutes per day of each cardio type, over the window.
    public var cardioMinutesPerDayByType: [String: Double]
    /// Apple Watch active energy averaged over rest days and training days in the window.
    public var watchActiveRestDay: Double?
    public var watchActiveTrainingDay: Double?
    public var daysInWindow: Int

    public init(stepsPerDay: Double = 0, liftSessionMinutes: Double = 60, liftStyle: String? = nil, liftDaysPerWeek: Double = 0, cardioMinutesPerDayByType: [String: Double] = [:], watchActiveRestDay: Double? = nil, watchActiveTrainingDay: Double? = nil, daysInWindow: Int = 0) {
        self.stepsPerDay = stepsPerDay
        self.liftSessionMinutes = liftSessionMinutes
        self.liftStyle = liftStyle
        self.liftDaysPerWeek = liftDaysPerWeek
        self.cardioMinutesPerDayByType = cardioMinutesPerDayByType
        self.watchActiveRestDay = watchActiveRestDay
        self.watchActiveTrainingDay = watchActiveTrainingDay
        self.daysInWindow = daysInWindow
    }

    /// Builds the profile from the days in the trust window (the `windowDays` days ending today).
    public static func from(log: [DayInput], today: Date, dials: Dials, calendar: Calendar) -> ActivityProfile {
        let n = max(1, dials.trustWindowDays)
        let window = log.filter { day in
            let idx = calendar.days(from: day.date, to: today)
            return idx >= 0 && idx < n
        }
        var profile = ActivityProfile()
        profile.daysInWindow = window.count

        let stepDays = window.compactMap { $0.steps }.map(Double.init)
        profile.stepsPerDay = stepDays.mean ?? 0

        let liftDays = window.filter { $0.hasLift }
        switch dials.liftDurationSource {
        case .fixed:
            profile.liftSessionMinutes = dials.fixedLiftMinutes
        case .workouts:
            profile.liftSessionMinutes = liftDays.compactMap { $0.liftMinutes }.mean ?? dials.fixedLiftMinutes
        }
        profile.liftStyle = liftDays.sorted { $0.date > $1.date }.first?.liftStyle ?? dials.defaultLiftStyle

        switch dials.trainingDayDetection {
        case .schedule:
            profile.liftDaysPerWeek = Double(Set(dials.scheduledTrainingWeekdays).count)
        case .workout, .manual:
            let trainingDays = window.filter { isTrainingDay($0, dials: dials, calendar: calendar) }.count
            let span = max(1, min(n, window.isEmpty ? n : (calendar.days(from: window.map(\.date).min()!, to: today) + 1)))
            profile.liftDaysPerWeek = Double(trainingDays) * 7 / Double(span)
        }

        var cardio: [String: Double] = [:]
        for day in window {
            for s in day.cardioSessions {
                cardio[s.type, default: 0] += s.minutes
            }
        }
        let divisor = Double(max(1, window.count))
        profile.cardioMinutesPerDayByType = cardio.mapValues { $0 / divisor }

        let watchRest = window.filter { !isTrainingDay($0, dials: dials, calendar: calendar) }.compactMap { $0.activeEnergyKcal }
        let watchTrain = window.filter { isTrainingDay($0, dials: dials, calendar: calendar) }.compactMap { $0.activeEnergyKcal }
        profile.watchActiveRestDay = watchRest.mean
        profile.watchActiveTrainingDay = watchTrain.mean
        return profile
    }

    /// Whether a logged day counts as a training day under the detection dial and manual override.
    public static func isTrainingDay(_ day: DayInput, dials: Dials, calendar: Calendar) -> Bool {
        if let override = day.liftingOverride { return override }
        switch dials.trainingDayDetection {
        case .workout: return day.hasLift
        case .schedule: return dials.scheduledTrainingWeekdays.contains(calendar.component(.weekday, from: day.date))
        case .manual: return false
        }
    }
}

public struct FormulaTDEEResult: Equatable, Sendable {
    public let bmr: Double
    public let dailyLiving: Double
    public let steps: Double
    public let cardio: Double
    /// kcal of one lifting session, after the post-workout burn.
    public let lift: Double
    public let tef: Double
    public let adaptationFactor: Double
    public let modeledRest: Double
    public let modeledTraining: Double
    public let watchRest: Double?
    public let watchTraining: Double?
    public let restDay: Double
    public let trainingDay: Double

    public func weeklyAverage(liftDaysPerWeek: Double) -> Double {
        let lift = min(7, max(0, liftDaysPerWeek))
        return (trainingDay * lift + restDay * (7 - lift)) / 7
    }
}

public enum FormulaTDEE {

    public static func compute(bmr: Double, weightLb: Double, activity: ActivityProfile, tef: Double, dials: Dials) -> FormulaTDEEResult {
        let wKg = Units.kg(fromLb: weightLb)
        let a = min(max(dials.metabolicAdaptationPercent / 100, 0), 0.9)
        let keep = 1 - a

        let living = bmr * dials.dailyLivingPercent / 100
        let steps = activity.stepsPerDay * wKg * dials.stepCostKcalPerStepPerKg
        let cardio = activity.cardioMinutesPerDayByType.reduce(0.0) { acc, pair in
            acc + max(0, dials.met(forCardioType: pair.key) - 1) * wKg * pair.value / 60
        }
        let liftMET = dials.met(forLiftStyle: activity.liftStyle)
        let lift = max(0, liftMET - 1) * wKg * activity.liftSessionMinutes / 60 * (1 + dials.postWorkoutBurnPercent / 100)

        let modeledRest = (bmr + living + steps + cardio) * keep + tef
        let modeledTraining = modeledRest + lift * keep

        var watchRest: Double?
        var watchTraining: Double?
        if let rest = activity.watchActiveRestDay {
            watchRest = (bmr + living + rest * dials.watchCorrection) * keep + tef
            if let train = activity.watchActiveTrainingDay {
                watchTraining = (bmr + living + train * dials.watchCorrection) * keep + tef
            } else {
                watchTraining = (watchRest ?? 0) + lift * keep
            }
        } else if let train = activity.watchActiveTrainingDay {
            // Only training-day Watch data: back out the lift to get a rest estimate.
            watchTraining = (bmr + living + train * dials.watchCorrection) * keep + tef
            watchRest = max(bmr + living, (watchTraining ?? 0) - lift * keep)
        }

        var rest = modeledRest
        var training = modeledTraining
        switch dials.activitySource {
        case .modeled:
            break
        case .watch:
            if let wr = watchRest, let wt = watchTraining {
                rest = wr
                training = wt
            }
        case .blend:
            if let wr = watchRest, let wt = watchTraining {
                let s = min(max(dials.activityBlendWatchShare, 0), 1)
                rest = modeledRest * (1 - s) + wr * s
                training = modeledTraining * (1 - s) + wt * s
            }
        }

        return FormulaTDEEResult(bmr: bmr, dailyLiving: living, steps: steps, cardio: cardio, lift: lift, tef: tef, adaptationFactor: keep, modeledRest: modeledRest, modeledTraining: modeledTraining, watchRest: watchRest, watchTraining: watchTraining, restDay: rest, trainingDay: training)
    }
}
