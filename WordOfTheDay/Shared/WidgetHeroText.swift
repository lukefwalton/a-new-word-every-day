import SwiftUI
import LFWDesignSystem

/// The day's word rendered at rest weight in the user's variable typeface, with a
/// soft accent glow behind it. Shared by the Home Screen widget
/// (`WordWidgetView`) and the Settings live preview (`WidgetPreviewCard`) so the
/// two render the hero identically and can't visually drift.
///
/// Distinct from `HeroWordView`, the app's *animated* hero (its weight axis
/// settles in on appear). This one is static — for contexts that don't animate,
/// like the widget and its preview.
struct WidgetHeroText: View {
    let word: String
    let typeface: LFWTypeface
    /// The word's fill (typically `palette.primaryText`).
    let color: Color
    /// The glow tint (typically `palette.accent`); its opacity is applied here.
    let glow: Color
    let size: CGFloat
    var minimumScaleFactor: CGFloat = 0.45

    /// Variable-font axes: rest weight, plus optical size when the face supports it.
    private var axes: [Int: CGFloat] {
        var axes: [Int: CGFloat] = [LFWVariableFont.weight: 560]
        if typeface.hasOpticalSize {
            axes[LFWVariableFont.opticalSize] = min(max(size, 9), 144)
        }
        return axes
    }

    var body: some View {
        Group {
            if LFWVariableFont.isRegistered(typeface.family) {
                Text(word)
                    .font(.lfwVariable(typeface.family, size: size, axes: axes))
            } else {
                Text(word)
                    .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(minimumScaleFactor)
        .accessibilityAddTraits(.isHeader)
        .background(
            Circle()
                .fill(glow.opacity(0.16))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 30)
        )
    }
}
