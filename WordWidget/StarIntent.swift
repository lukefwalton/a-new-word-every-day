import AppIntents
import WidgetKit

/// Toggles a word's star straight from the widget (iOS 17 interactive widgets).
/// It writes to the same App Group store the app reads, so the Practice list
/// updates with no app launch. This is *why* the deployment target is iOS 17.
struct ToggleStarIntent: AppIntent {
    static var title: LocalizedStringResource = "Save or unsave this word"
    static var isDiscoverable = false

    @Parameter(title: "Word ID")
    var wordID: Int

    init() {}
    init(wordID: Int) { self.wordID = wordID }

    func perform() async throws -> some IntentResult {
        SharedStore.shared.toggleStar(wordID)
        // WidgetKit reloads after an interactive intent, but request it explicitly
        // so the star glyph (read from the timeline entry) can't render stale.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
