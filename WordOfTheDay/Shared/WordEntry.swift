import WidgetKit

/// One timeline entry — a day and its word, plus the resolved theme, widget prefs,
/// and star state. Shared by the widget extension and the in-app Settings preview.
struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word?
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences
    let isStarred: Bool
}
