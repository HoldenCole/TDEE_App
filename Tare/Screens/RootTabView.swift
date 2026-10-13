import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            TabView(selection: $model.selectedTab) {
                TodayView()
                    .tabItem { Label("Today", systemImage: "circle.circle") }
                    .tag(AppTab.today)
                TrendView()
                    .tabItem { Label("Trend", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(AppTab.trend)
                ProgressTabView()
                    .tabItem { Label("Progress", systemImage: "dumbbell") }
                    .tag(AppTab.progress)
                PlanView()
                    .tabItem { Label("Plan", systemImage: "flag") }
                    .tag(AppTab.plan)
                DialsView()
                    .tabItem { Label("Dials", systemImage: "slider.horizontal.3") }
                    .tag(AppTab.dials)
            }
            .tint(Theme.ink)

            if let toast = model.toast {
                ToastView(toast: toast) { model.toast = nil }
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(10))
                        if model.toast?.id == toast.id { model.toast = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
        .sheet(item: $model.detailNumber) { number in
            NumberDetailSheet(number: number)
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.sheetRadius)
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            configureTabBar()
        }
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = .clear
        let item = appearance.stackedLayoutAppearance
        item.normal.iconColor = UIColor(Theme.tertiary)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.tertiary), .font: UIFont.systemFont(ofSize: 11, weight: .medium)]
        item.selected.iconColor = UIColor(Theme.ink)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.ink), .font: UIFont.systemFont(ofSize: 11, weight: .semibold)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
