import SwiftUI
import LFWDesignSystem

/// A live preview of the Home Screen medium widget using the user's current theme
/// and widget preferences — shown in Settings so customization feels immediate.
/// Mirrors the widget's background, layout, and detail choices.
struct WidgetPreviewCard: View {
    let word: Word
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences

    private var typeface: LFWTypeface { theme.typeface }
    private var palette: LFWPaletteColors { theme.colors }
    private var detail: WidgetDetailLevel { widgetPreferences.detailLevel }
    private var layout: WidgetLayoutStyle { widgetPreferences.layoutStyle }

    var body: some View {
        ZStack {
            WidgetBackground(theme: theme, style: widgetPreferences.backgroundStyle)
            content
                .padding(layout == .minimal ? 0 : 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 158)
        .clipShape(RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Widget preview showing \(word.word)")
    }

    @ViewBuilder
    private var content: some View {
        if layout == .minimal {
            minimal
        } else {
            framed(centered: layout.isCentered)
        }
    }

    private func framed(centered: Bool) -> some View {
        let elementAlignment: Alignment = centered ? .center : .leading
        let defLimit = detail.definitionLines(family: .medium)
        return VStack(alignment: centered ? .center : .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WORD OF THE DAY")
                        .font(LFWTypography.font(.eyebrow, typeface: typeface, size: 9))
                        .kerning(1.5)
                        .foregroundStyle(palette.accent)
                    Capsule().fill(palette.accent).frame(width: 20, height: 2.5)
                }
                Spacer(minLength: 4)
                Image(systemName: "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
            WidgetHeroText(word: word.word, typeface: typeface,
                           color: palette.primaryText, glow: palette.accent, size: 34)
                .frame(maxWidth: .infinity, alignment: elementAlignment)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: 12))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, alignment: elementAlignment)
            if defLimit > 0 {
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface, size: 14))
                    .foregroundStyle(palette.primaryText.opacity(0.94))
                    .lineLimit(defLimit)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: elementAlignment)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centered ? .top : .topLeading)
        .background(
            RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                .fill(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                        .strokeBorder(palette.primaryText.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var minimal: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            WidgetHeroText(word: word.word, typeface: typeface,
                           color: palette.primaryText, glow: palette.accent, size: 40)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: 13))
                .foregroundStyle(palette.accent)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .padding(14)
        }
    }

}
