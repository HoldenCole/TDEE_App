import AppIntents
import Foundation

/// "What's my target today?" for Siri and Shortcuts. Reads the snapshot the app writes
/// for the widget, so it answers without launching the app.
struct TodayTargetIntent: AppIntent {
    static var title: LocalizedStringResource = "What's my target today?"
    static var description = IntentDescription("Tells you today's calorie target and what's left.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        guard let s = WidgetSnapshot.load() else {
            return .result(value: 0, dialog: "Open Tare once so it can work out your target.")
        }
        let target = Int(s.targetCalories.rounded())
        let remaining = Int(s.remaining.rounded())
        let day = s.isTrainingDay ? "training day" : "rest day"
        let dialog: IntentDialog = remaining > 0
            ? "Your target is \(target) calories on a \(day). You have \(remaining) left."
            : "Your target is \(target) calories on a \(day). You're \(-remaining) over."
        return .result(value: remaining, dialog: dialog)
    }
}

struct TareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayTargetIntent(),
            phrases: [
                "What's my target in \(.applicationName)",
                "How many calories do I have left in \(.applicationName)",
                "\(.applicationName) target",
            ],
            shortTitle: "Today's target",
            systemImageName: "flame"
        )
    }
}
