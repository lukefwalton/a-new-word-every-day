import SwiftUI
import LFWDesignSystem

@main
struct WordOfTheDayApp: App {
    @StateObject private var model = AppModel(service: DailyWordService(corpus: .load()))
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // One-time diagnostic: confirm each bundled variable font's real family
        // name + axes. An empty axes map means the .ttf isn't bundled yet (run
        // scripts/fetch_fonts.sh) or LFWTypeface.family doesn't match Core Text.
        for face in LFWTypeface.allCases {
            let family = face.family
            let axes = LFWVariableFont.axes(of: family)
            print("[WordOfTheDay] \(face.displayName) family=\(family) registered=\(LFWVariableFont.isRegistered(family)) axes=\(axes.keys.sorted())")
        }
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
