import SwiftUI
import LFWDesignSystem

/// The widget's backdrop, chosen by `WidgetBackgroundStyle`. Lives in `Shared/` so
/// both the widget (as its `containerBackground`) and the in-app Settings preview
/// render the exact same backdrop. Only SwiftUI + the design system — no WidgetKit.
public struct WidgetBackground: View {
    public let theme: LFWThemeConfig
    public let style: WidgetBackgroundStyle

    public init(theme: LFWThemeConfig, style: WidgetBackgroundStyle) {
        self.theme = theme
        self.style = style
    }

    private var palette: LFWPaletteColors { theme.colors }

    public var body: some View {
        switch style {
        case .blobs:
            LFWThemedBackground(config: theme, animated: false)
        case .gradient:
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .accent:
            ZStack {
                LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [palette.accent.opacity(0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 280)
            }
        }
    }
}
