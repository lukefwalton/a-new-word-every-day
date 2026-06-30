import WidgetKit
import SwiftUI
import AppIntents
import LFWDesignSystem

/// Renders an entry across all supported families. Home Screen families use the
/// full themed presentation (background, variable hero type, optional surface card);
/// lock-screen accessories stay compact but still use the user's typeface.
///
/// The look is driven by the user's `WidgetPreferences`: background style, layout
/// style, and detail level, on top of the `LFWThemeConfig` (typeface + palette).
struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var typeface: LFWTypeface { entry.theme.typeface }
    private var palette: LFWPaletteColors { entry.theme.colors }
    private var detail: WidgetDetailLevel { entry.widgetPreferences.detailLevel }
    private var layout: WidgetLayoutStyle { entry.widgetPreferences.layoutStyle }

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

    @ViewBuilder
    private func homeScreen(_ word: Word, size: WidgetLayoutSize) -> some View {
        Group {
            if layout == .minimal {
                minimalBody(word, size: size)
            } else {
                framedBody(word, size: size, centered: layout.isCentered)
            }
        }
        .widgetURL(deepLink(word))
    }

    /// Editorial (left) and Centered layouts: eyebrow + star header, hero, part of
    /// speech, definition, on a translucent surface card.
    private func framedBody(_ word: Word, size: WidgetLayoutSize, centered: Bool) -> some View {
        let heroSize = heroSize(size, minimal: false)
        let defSize: CGFloat = size == .extraLarge ? 19 : (size == .large ? 17 : 15)
        let defLines = detail.definitionLines(family: size)
        let padding: CGFloat = size == .small ? 14 : 16
        let elementAlignment: Alignment = centered ? .center : .leading

        return VStack(alignment: centered ? .center : .leading, spacing: size == .small ? 6 : 8) {
            header(word, compact: size == .small, starSize: size == .small ? 14 : 16)
            Spacer(minLength: 0)
            heroBlock(word, size: heroSize)
                .frame(maxWidth: .infinity, alignment: elementAlignment)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: size == .small ? 11 : 13))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, alignment: elementAlignment)
                .multilineTextAlignment(centered ? .center : .leading)
            if defLines > 0 {
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface, size: defSize))
                    .foregroundStyle(palette.primaryText.opacity(0.94))
                    .lineLimit(defLines)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: elementAlignment)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centered ? .top : .topLeading)
        .background(cardChrome)
    }

    /// Minimal layout: just the word + part of speech, centered and type-forward, on
    /// the bare background (no card, no eyebrow). The star stays reachable, tucked in
    /// the top-trailing corner.
    private func minimalBody(_ word: Word, size: WidgetLayoutSize) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            heroBlock(word, size: heroSize(size, minimal: true))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: size == .small ? 11 : 14))
                .foregroundStyle(palette.accent)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(size == .small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            starButton(word, size: size == .small ? 14 : 16)
        }
    }

    private func heroSize(_ size: WidgetLayoutSize, minimal: Bool) -> CGFloat {
        switch size {
        case .small:      return minimal ? 40 : 32
        case .medium:     return minimal ? 46 : 36
        case .large:      return minimal ? 58 : 46
        case .extraLarge: return minimal ? 70 : 54
        }
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
            .fill(palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .strokeBorder(palette.primaryText.opacity(0.10), lineWidth: 1)
            )
    }

    private func header(_ word: Word, compact: Bool, starSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(compact ? "TODAY" : "WORD OF THE DAY")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface, size: compact ? 9 : 10))
                    .kerning(compact ? 1.2 : 1.5)
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // Decorative accent rule under the eyebrow.
                Capsule().fill(palette.accent).frame(width: 20, height: 2.5)
            }
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

    /// The hero word with a soft accent glow behind it — a designed, not just
    /// themed, presence.
    private func heroBlock(_ word: Word, size: CGFloat) -> some View {
        widgetHero(word, size: size)
            .foregroundStyle(palette.primaryText)
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
            .background(
                Circle()
                    .fill(palette.accent.opacity(0.16))
                    .frame(width: size * 1.7, height: size * 1.7)
                    .blur(radius: 30)
            )
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
