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
        store.band = 3

        if let today = service.todaysWord(store: store), !store.isStarred(today.id) {
            store.toggleStar(today.id)
        }
        for word in service.calibrationSample(salt: store.installSalt).prefix(2) {
            if !store.isStarred(word.id) { store.toggleStar(word.id) }
        }
    }
}
#endif
