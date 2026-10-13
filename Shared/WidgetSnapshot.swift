import Foundation

/// The App Group both the app and the widget extension belong to. Change it together with
/// `com.apple.security.application-groups` in project.yml if you use your own identifier.
public enum AppGroup {
    public static let identifier = "group.com.holdencole.tare"
    public static let snapshotFileName = "widget-snapshot.json"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// What the widget shows. The app writes it after every recompute; the widget only reads.
public struct WidgetSnapshot: Codable, Equatable {
    public var date: Date
    public var targetCalories: Double
    public var eatenCalories: Double
    public var isTrainingDay: Bool
    public var proteinEaten: Double
    public var proteinTarget: Double

    public var remaining: Double { targetCalories - eatenCalories }
    public var progress: Double { targetCalories > 0 ? min(1, max(0, eatenCalories / targetCalories)) : 0 }

    public init(date: Date, targetCalories: Double, eatenCalories: Double, isTrainingDay: Bool, proteinEaten: Double, proteinTarget: Double) {
        self.date = date
        self.targetCalories = targetCalories
        self.eatenCalories = eatenCalories
        self.isTrainingDay = isTrainingDay
        self.proteinEaten = proteinEaten
        self.proteinTarget = proteinTarget
    }

    public static let placeholder = WidgetSnapshot(date: Date(), targetCalories: 3420, eatenCalories: 1840, isTrainingDay: true, proteinEaten: 128, proteinTarget: 190)

    static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(AppGroup.snapshotFileName)
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func save() {
        guard let url = WidgetSnapshot.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
