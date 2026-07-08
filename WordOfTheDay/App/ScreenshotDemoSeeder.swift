#if DEBUG
import Foundation
import LFWDesignSystem

/// Polished on-device state for App Store screenshots (see
/// `scripts/capture_app_store_screenshots.sh`).
enum ScreenshotDemoSeeder {
    static func seed(store: SharedStore, service: DailyWordService) {
        store.theme = LFWThemeConfig(typeface: .fraunces, palette: .deepSea, accentHueShift: 0)
        store.widgetPreferences = WidgetPreferences(
            detailLevel: .rich,
            backgroundStyle: .blobs,
            layoutStyle: .editorial
        )
        store.setBand(3, for: .english)

        if let today = service.todaysWord(store: store, language: .english), !store.isStarred(today.id) {
            store.toggleStar(today.id)
        }
        for word in service.calibrationSample(language: .english, salt: store.installSalt).prefix(2) {
            if !store.isStarred(word.id) { store.toggleStar(word.id) }
        }
    }
}
#endif
