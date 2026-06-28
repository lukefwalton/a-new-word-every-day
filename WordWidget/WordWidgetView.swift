import WidgetKit
import SwiftUI
import AppIntents
import LFWDesignSystem

/// Renders an entry across all supported families. Home Screen families get the
/// themed type + an interactive star; lock-screen accessories stay monochrome and
/// minimal per the system's rendering.
struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var typeface: LFWTypeface { entry.theme.typeface }
    private var palette: LFWPaletteColors { entry.theme.colors }

    var body: some View {
        if let word = entry.word {
            switch family {
            case .accessoryInline:
                Text("\(word.word) · \(word.partOfSpeechLabel)")
            case .accessoryRectangular:
                accessoryRectangular(word)
            case .systemSmall:
                small(word)
            default:
                medium(word)
            }
        } else {
            Text("Open Word of the Day").font(.caption)
        }
    }

    // MARK: Home Screen

    private func small(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(word, compact: true)
            Spacer(minLength: 0)
            wordText(word, size: 30)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: 12))
                .foregroundStyle(palette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(deepLink(word))
    }

    private func medium(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(word, compact: false)
            wordText(word, size: family == .systemLarge ? 44 : 34)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: 13))
                .foregroundStyle(palette.accent)
            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface, size: family == .systemLarge ? 18 : 15))
                .foregroundStyle(palette.primaryText.opacity(0.92))
                .lineLimit(family == .systemLarge ? 4 : 2)
            if family == .systemLarge, !word.example.isEmpty {
                Text("“\(word.example)”")
                    .font(LFWTypography.font(.example, typeface: typeface, size: 15))
                    .italic()
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(deepLink(word))
    }

    private func header(_ word: Word, compact: Bool) -> some View {
        HStack {
            Text(compact ? "TODAY" : "WORD OF THE DAY")
                .font(LFWTypography.font(.eyebrow, typeface: typeface, size: 10))
                .kerning(1.5)
                .foregroundStyle(palette.accent)
            Spacer()
            starButton(word)
        }
    }

    @ViewBuilder
    private func starButton(_ word: Word) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleStarIntent(wordID: word.id)) {
                Image(systemName: entry.isStarred ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(entry.isStarred ? palette.accent : palette.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private func wordText(_ word: Word, size: CGFloat) -> some View {
        // Static (non-animated) render for the widget; HeroWordView's appear
        // animation isn't meaningful in a timeline snapshot.
        Text(word.word)
            .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
            .foregroundStyle(palette.primaryText)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    // MARK: Lock screen

    private func accessoryRectangular(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.word).font(.headline)
            Text(word.definition).font(.caption2).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(deepLink(word))
    }

    private func deepLink(_ word: Word) -> URL? {
        URL(string: "wordoftheday://word/\(word.id)")
    }
}
