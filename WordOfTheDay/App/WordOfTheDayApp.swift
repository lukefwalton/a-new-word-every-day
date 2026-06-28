import SwiftUI
import LFWDesignSystem

@main
struct WordOfTheDayApp: App {
    @StateObject private var model = AppModel(service: DailyWordService(corpus: .load()))
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // One-time diagnostic: confirm the bundled variable font's real family
        // name + axes. An empty result means the .ttf isn't bundled yet (run
        // scripts/fetch_fonts.sh) and the UI is using the system fallback.
        let family = LFWThemeConfig.default.typeface.family
        let axes = LFWVariableFont.axes(of: family)
        print("[WordOfTheDay] \(family) registered=\(LFWVariableFont.isRegistered(family)) axes=\(axes.keys.sorted())")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(model.theme.colors.accent)
                .preferredColorScheme(model.theme.palette.isDark ? .dark : .light)
                .onOpenURL { model.handle(url: $0) }
                // Re-read the shared store on foreground so the day's word rolls
                // over at midnight and widget-side star changes show immediately.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshFromStore() }
                }
        }
    }
}
