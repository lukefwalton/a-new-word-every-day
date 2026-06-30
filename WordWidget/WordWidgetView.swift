import WidgetKit
import SwiftUI
import AppIntents
import LFWDesignSystem

/// Renders an entry across all supported families. Home Screen families use the
/// full themed presentation (blobs, variable hero type, surface card); lock-screen
/// accessories stay compact but still use the user's typeface where allowed.
struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var typeface: LFWTypeface { entry.theme.typeface }
    private var palette: LFWPaletteColors { entry.theme.colors }
    private var detail: WidgetDetailLevel { entry.widgetPreferences.detailLevel }

    var body: some View {
        if let word = entry.word {
            switch family {
            case .accessoryInline:
                accessoryInline(word)
            case .accessoryRectangular:
                accessoryRectangular(word)
            case .systemSmall:
                homeScreen(word, size: .small)
            case .systemLarge:
                homeScreen(word, size: .large)
            default:
                if #available(iOSApplicationExtension 17.0, *), family == .systemExtraLarge {
                    homeScreen(word, size: .extraLarge)
                } else {
                    homeScreen(word, size: .medium)
                }
            }
        } else {
            Text("Open Word of the Day")
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 13))
                .foregroundStyle(palette.secondaryText)
        }
    }

    // MARK: Home Screen

    private func homeScreen(_ word: Word, size: WidgetLayoutSize) -> some View {
        let heroSize: CGFloat = {
            switch size {
            case .small:      return 32
            case .medium:     return 36
            case .large:      return 46
            case .extraLarge: return 54
            }
        }()
        let defSize: CGFloat = size == .extraLarge ? 19 : (size == .large ? 17 : 15)
        let defLines = detail.definitionLines(family: size)
        let padding: CGFloat = size == .small ? 14 : 16

        return VStack(alignment: .leading, spacing: size == .small ? 6 : 8) {
            header(word, compact: size == .small, starSize: size == .small ? 14 : 16)
            Spacer(minLength: 0)
            widgetHero(word, size: heroSize)
                .foregroundStyle(palette.primaryText)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: size == .small ? 11 : 13))
                .foregroundStyle(palette.accent)
            if defLines > 0 {
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface, size: defSize))
                    .foregroundStyle(palette.primaryText.opacity(0.94))
                    .lineLimit(defLines)
                    .minimumScaleFactor(0.85)
            }
            if size == .extraLarge {
                Text("Tap to open · star to save")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface, size: 10))
                    .kerning(1.2)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                .fill(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                        .strokeBorder(palette.primaryText.opacity(0.10), lineWidth: 1)
                )
        )
        .widgetURL(deepLink(word))
    }

    private func header(_ word: Word, compact: Bool, starSize: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(compact ? "TODAY" : "WORD OF THE DAY")
                .font(LFWTypography.font(.eyebrow, typeface: typeface, size: compact ? 9 : 10))
                .kerning(compact ? 1.2 : 1.5)
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            starButton(word, size: starSize)
        }
    }

    @ViewBuilder
    private func starButton(_ word: Word, size: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleStarIntent(wordID: word.id)) {
                Image(systemName: entry.isStarred ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(entry.isStarred ? palette.accent : palette.secondaryText)
                    .frame(width: max(size + 12, 32), height: max(size + 12, 32))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isStarred ? "Remove from practice list" : "Save to practice list")
        }
    }

    /// Variable-font hero at rest weight — richer than static `LFWTypography.font`.
    @ViewBuilder
    private func widgetHero(_ word: Word, size: CGFloat) -> some View {
        if LFWVariableFont.isRegistered(typeface.family) {
            Text(word.word)
                .font(.lfwVariable(typeface.family, size: size, axes: heroAxes(size: size)))
        } else {
            Text(word.word)
                .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
        }
    }

    private func heroAxes(size: CGFloat) -> [Int: CGFloat] {
        var axes: [Int: CGFloat] = [LFWVariableFont.weight: 560]
        if typeface.hasOpticalSize {
            axes[LFWVariableFont.opticalSize] = min(max(size, 9), 144)
        }
        return axes
    }

    // MARK: Lock screen

    private func accessoryInline(_ word: Word) -> some View {
        Text("\(word.word) · \(word.partOfSpeechLabel)")
            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 12))
            .widgetURL(deepLink(word))
    }

    private func accessoryRectangular(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.word)
                .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 15))
                .lineLimit(1)
            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface, size: 11))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(deepLink(word))
    }

    private func deepLink(_ word: Word) -> URL? {
        URL(string: "wordoftheday://word/\(word.id)")
    }
}
