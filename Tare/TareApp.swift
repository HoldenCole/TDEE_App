import SwiftUI
import SwiftData

@main
struct TareApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = Persistence.makeContainer()
        self.container = container
        _model = State(initialValue: AppModel(container: container))
    }

    /// `-TareForceDark` / `-TareForceLight` pin the appearance for screenshots; otherwise follow the system.
    private var forcedScheme: ColorScheme? {
        let args = CommandLine.arguments
        if args.contains("-TareForceDark") { return .dark }
        if args.contains("-TareForceLight") { return .light }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.onboarded {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environment(model)
            .modelContainer(container)
            .preferredColorScheme(forcedScheme)
            .tint(Theme.accent)
            .task {
                model.startHealthBackgroundDelivery()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, model.onboarded else { return }
                Task { await model.refreshOnForeground() }
            }
        }
    }
}
