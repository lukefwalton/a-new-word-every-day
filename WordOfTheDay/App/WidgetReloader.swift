import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Nudges the widget to recompute after the app changes shared state (a star,
/// the theme, the difficulty band). The widget reads the same App Group state, so
/// this just asks it to refresh now rather than at the next daily reload.
enum WidgetReloader {
    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
