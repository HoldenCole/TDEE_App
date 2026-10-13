import Foundation
import TareEngine

/// Small, non-record state kept in the App Group's UserDefaults: the active dials, flags and sync markers.
struct AppState {
    private static let defaults = AppGroup.defaults

    private enum Key {
        static let dials = "tare.dials"
        static let onboarded = "tare.onboarded"
        static let firstLaunch = "tare.firstLaunch"
        static let lastCheckIn = "tare.lastCheckIn"
        static let rateMisses = "tare.rateMisses"
        static let progressLock = "tare.progressLock"
        static let hevyLastSync = "tare.hevyLastSync"
        static let healthLastSync = "tare.healthLastSync"
        static let healthAuthorized = "tare.healthAuthorized"
        static let activePreset = "tare.activePreset"
    }

    static func loadDials() -> Dials {
        guard let data = defaults.data(forKey: Key.dials), let d = try? Dials.decode(json: data) else { return Dials() }
        return d
    }

    static func saveDials(_ dials: Dials) {
        if let data = try? dials.encodedJSON() { defaults.set(data, forKey: Key.dials) }
    }

    static var onboarded: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }

    static var firstLaunch: Date {
        if let d = defaults.object(forKey: Key.firstLaunch) as? Date { return d }
        let now = Date()
        defaults.set(now, forKey: Key.firstLaunch)
        return now
    }

    static var lastCheckIn: Date? {
        get { defaults.object(forKey: Key.lastCheckIn) as? Date }
        set { defaults.set(newValue, forKey: Key.lastCheckIn) }
    }

    static var rateMisses: Int {
        get { defaults.integer(forKey: Key.rateMisses) }
        set { defaults.set(newValue, forKey: Key.rateMisses) }
    }

    static var progressLockEnabled: Bool {
        get { defaults.bool(forKey: Key.progressLock) }
        set { defaults.set(newValue, forKey: Key.progressLock) }
    }

    static var hevyLastSync: Date? {
        get { defaults.object(forKey: Key.hevyLastSync) as? Date }
        set { defaults.set(newValue, forKey: Key.hevyLastSync) }
    }

    static var healthLastSync: Date? {
        get { defaults.object(forKey: Key.healthLastSync) as? Date }
        set { defaults.set(newValue, forKey: Key.healthLastSync) }
    }

    static var healthAuthorized: Bool {
        get { defaults.bool(forKey: Key.healthAuthorized) }
        set { defaults.set(newValue, forKey: Key.healthAuthorized) }
    }

    static var activePresetName: String? {
        get { defaults.string(forKey: Key.activePreset) }
        set { defaults.set(newValue, forKey: Key.activePreset) }
    }
}
