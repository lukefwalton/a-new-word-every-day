import SwiftUI

/// Onboarding gate + the three-tab shell. Mirrors the family pattern: an
/// `@AppStorage`-style completion flag (here on the shared store) flips between
/// onboarding and the app.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.onboardingComplete {
                TabView(selection: $model.selectedTab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.max.fill") }
                        .tag(AppModel.Tab.today)
                    PracticeView()
                        .tabItem { Label("Practice", systemImage: "star.fill") }
                        .tag(AppModel.Tab.practice)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                        .tag(AppModel.Tab.settings)
                }
                .tint(model.theme.colors.accent)
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.onboardingComplete)
        .onAppear { TabBarAppearance.apply(theme: model.theme) }
        .onChange(of: model.theme) { _, theme in TabBarAppearance.apply(theme: theme) }
    }
}
