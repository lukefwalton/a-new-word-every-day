import SwiftUI

/// Onboarding gate + the three-tab shell. Mirrors the family pattern: an
/// `@AppStorage`-style completion flag (here on the shared store) flips between
/// onboarding and the app.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .today

    enum Tab: Hashable { case today, practice, settings }

    var body: some View {
        Group {
            if model.onboardingComplete {
                TabView(selection: $tab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.max.fill") }
                        .tag(Tab.today)
                    PracticeView()
                        .tabItem { Label("Practice", systemImage: "star.fill") }
                        .tag(Tab.practice)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                        .tag(Tab.settings)
                }
                .onChange(of: model.focusedWordID) { _, id in
                    if id != nil { tab = .today }
                }
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.onboardingComplete)
    }
}
