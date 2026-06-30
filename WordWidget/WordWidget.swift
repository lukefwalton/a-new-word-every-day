import WidgetKit
import SwiftUI
import LFWDesignSystem

/// One timeline entry — a day and its word, plus theme, widget prefs, and star
/// state read from the shared store. The word is computed deterministically, so
/// the widget always matches the app without any shared write.
struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word?
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences
    let isStarred: Bool
}

struct WordProvider: TimelineProvider {
    private let service = DailyWordService(corpus: .load(bundles: [.main]))

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(),
                  word: service.corpus.words.first,
                  theme: .default,
                  widgetPreferences: .default,
                  isStarred: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<5).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map(entry(for:))
        }
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func entry(for date: Date) -> WordEntry {
        let store = SharedStore.shared
        let word = service.todaysWord(store: store, now: date)
        return WordEntry(date: date,
                         word: word,
                         theme: store.theme,
                         widgetPreferences: store.widgetPreferences,
                         isStarred: word.map { store.isStarred($0.id) } ?? false)
    }
}

struct WordWidget: Widget {
    let kind = "WordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LFWThemedBackground(config: entry.theme, animated: false)
                }
        }
        .configurationDisplayName("Word of the Day")
        .description("Your daily word — typeface, colors, and layout you choose in Settings.")
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
