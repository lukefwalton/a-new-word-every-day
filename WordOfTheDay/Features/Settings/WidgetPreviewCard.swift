import SwiftUI
import LFWDesignSystem

/// Live preview of the Home Screen medium widget in Settings. Renders the same
/// `WordWidgetView` the extension uses so the preview can't drift from the real widget.
struct WidgetPreviewCard: View {
    /// Medium widget height on iPhone (~169 pt).
    static let previewHeight: CGFloat = 169

    let word: Word
    let theme: LFWThemeConfig
    let widgetPreferences: WidgetPreferences

    private var palette: LFWPaletteColors { theme.colors }

    private var entry: WordEntry {
        WordEntry(date: .init(),
                  word: word,
                  theme: theme,
                  widgetPreferences: widgetPreferences,
                  isStarred: false)
    }

    var body: some View {
        ZStack(alignment: .top) {
            WidgetBackground(theme: theme, style: widgetPreferences.backgroundStyle)
            WordWidgetView(entry: entry, forcedFamily: .medium, interactiveStar: false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Widget preview showing \(word.word)")
    }
}
