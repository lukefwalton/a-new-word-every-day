#if DEBUG
import Foundation
import LFWDesignSystem

/// Polished on-device state for App Store screenshots (see
/// `scripts/capture_app_store_screenshots.sh`). Pass `-ScreenshotDemoJapanese`
/// for a Japanese-only set, or default to English-only.
enum ScreenshotDemoSeeder {
    enum Mode {
        case english
        case japanese

        static func current() -> Mode {
            Set(ProcessInfo.processInfo.arguments).contains("-ScreenshotDemoJapanese") ? .japanese : .english
        }
    }

    static func seed(store: SharedStore, service: DailyWordService) {
        store.theme = LFWThemeConfig(typeface: .fraunces, palette: .deepSea, accentHueShift: 0)
        store.widgetPreferences = WidgetPreferences(
            detailLevel: .rich,
            backgroundStyle: .blobs,
            layoutStyle: .editorial
        )

        switch Mode.current() {
        case .english:
            store.enabledLanguages = [.english]
            polish(language: .english, store: store, service: service)
        case .japanese:
            store.enabledLanguages = [.japanese]
            polish(language: .japanese, store: store, service: service)
        }
    }

    private static func polish(language: Language, store: SharedStore, service: DailyWordService) {
        store.setBand(3, for: language)

        if let today = service.todaysWord(store: store, language: language), !store.isStarred(today.id) {
            store.toggleStar(today.id)
        }
        for word in service.calibrationSample(language: language, salt: store.installSalt).prefix(2) {
            if !store.isStarred(word.id) { store.toggleStar(word.id) }
        }
    }
}
#endif
