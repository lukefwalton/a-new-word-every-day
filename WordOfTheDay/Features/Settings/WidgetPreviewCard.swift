import SwiftUI
import LFWDesignSystem

/// A live preview of the Home Screen medium widget using the user's current theme
/// and widget preferences — shown in Settings so customization feels immediate.
struct WidgetPreviewCard: View {
    let word: Word
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences

    private var typeface: LFWTypeface { theme.typeface }
    private var palette: LFWPaletteColors { theme.colors }
    private var detail: WidgetDetailLevel { widgetPreferences.detailLevel }

    private var definitionLineLimit: Int { detail.definitionLines(family: .medium) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORD OF THE DAY")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface, size: 9))
                    .kerning(1.5)
                    .foregroundStyle(palette.accent)
                Spacer()
                Image(systemName: "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
            heroWord
            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface, size: 12))
                .foregroundStyle(palette.accent)
            if definitionLineLimit > 0 {
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface, size: 14))
                    .foregroundStyle(palette.primaryText.opacity(0.94))
                    .lineLimit(definitionLineLimit)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 158)
        .background(
            ZStack {
                LFWThemedBackground(config: theme, animated: false)
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .fill(palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                            .strokeBorder(palette.primaryText.opacity(0.10), lineWidth: 1)
                    )
                    .padding(10)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Widget preview showing \(word.word)")
    }

    @ViewBuilder
    private var heroWord: some View {
        let size: CGFloat = 34
        if LFWVariableFont.isRegistered(typeface.family) {
            Text(word.word)
                .font(.lfwVariable(typeface.family, size: size, axes: heroAxes(size: size)))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            Text(word.word)
                .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private func heroAxes(size: CGFloat) -> [Int: CGFloat] {
        var axes: [Int: CGFloat] = [LFWVariableFont.weight: 560]
        if typeface.hasOpticalSize {
            axes[LFWVariableFont.opticalSize] = min(max(size, 9), 144)
        }
        return axes
    }
}
