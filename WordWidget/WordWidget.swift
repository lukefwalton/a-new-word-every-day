import WidgetKit
import SwiftUI
import AppIntents
import LFWDesignSystem

/// One timeline entry — a day and its word, plus the resolved theme, widget prefs,
/// and star state. The word is computed deterministically, so the widget always
/// matches the app without any shared write; the look is resolved per widget from
/// its Edit-Widget configuration (falling back to the in-app defaults).
struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word?
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences
    let isStarred: Bool
}

struct WordProvider: AppIntentTimelineProvider {
    typealias Entry = WordEntry
    typealias Intent = WordWidgetConfigurationIntent

    private let service = DailyWordService(corpus: .load(bundles: [.main]))

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(),
                  word: service.corpus.words.first,
                  theme: .default,
                  widgetPreferences: .default,
                  isStarred: false)
    }

    func snapshot(for configuration: WordWidgetConfigurationIntent, in context: Context) async -> WordEntry {
        entry(for: Date(), configuration: configuration)
    }

    func timeline(for configuration: WordWidgetConfigurationIntent, in context: Context) async -> Timeline<WordEntry> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<5).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
                .map { entry(for: $0, configuration: configuration) }
        }
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return Timeline(entries: entries, policy: .after(nextMidnight))
    }

    /// Resolve this widget's configuration against the in-app defaults (App Group).
    /// Any option left as "App Default" (`resolved == nil`) falls back to the Settings
    /// value, so an unconfigured widget looks exactly as it did before.
    private func entry(for date: Date, configuration: WordWidgetConfigurationIntent) -> WordEntry {
        let store = SharedStore.shared
        let word = service.todaysWord(store: store, now: date)
        let baseTheme = store.theme
        let basePrefs = store.widgetPreferences

        let theme = LFWThemeConfig(
            typeface: configuration.typeface.resolved ?? baseTheme.typeface,
            palette: configuration.palette.resolved ?? baseTheme.palette,
            accentHueShift: baseTheme.accentHueShift)
        let prefs = WidgetPreferences(
            detailLevel: configuration.detail.resolved ?? basePrefs.detailLevel,
            backgroundStyle: configuration.background.resolved ?? basePrefs.backgroundStyle,
            layoutStyle: configuration.layout.resolved ?? basePrefs.layoutStyle)

        return WordEntry(date: date,
                         word: word,
                         theme: theme,
                         widgetPreferences: prefs,
                         isStarred: word.map { store.isStarred($0.id) } ?? false)
    }
}

struct WordWidget: Widget {
    let kind = "WordWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: WordWidgetConfigurationIntent.self,
                               provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(theme: entry.theme,
                                     style: entry.widgetPreferences.backgroundStyle)
                }
        }
        .configurationDisplayName("Word of the Day")
        .description("Your daily word — set this widget's look here, or keep your in-app defaults.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline,
        ]
        if #available(iOSApplicationExtension 17.0, *) {
            families.insert(.systemExtraLarge, at: 3)
        }
        return families
    }
}
