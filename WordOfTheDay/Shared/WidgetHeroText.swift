import SwiftUI
import LFWDesignSystem

/// The day's word rendered at rest weight in the user's variable typeface, with a
/// soft accent glow behind it. Shared by the Home Screen widget
/// (`WordWidgetView`) and the Settings live preview (`WidgetPreviewCard`) so the
/// two render the hero identically and can't visually drift.
///
/// Long words ("serendipity") can overflow the nominal size in a small widget, so
/// the hero steps down through fixed size candidates and takes the first that fits
/// on one line. Stepping keeps long words at a deliberate optical size (with a
/// matching glow) instead of continuously squeezing them; the smallest candidate
/// keeps a scale-factor backstop so no word ever truncates.
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
    /// Last-resort floor, applied only to the smallest candidate — the effective
    /// absolute floor is this × 0.55 of the nominal size (~0.3 by default).
    var minimumScaleFactor: CGFloat = 0.55

    var body: some View {
        ViewThatFits(in: .horizontal) {
            hero(at: size)
            hero(at: size * 0.85)
            hero(at: size * 0.7)
            hero(at: size * 0.55)
                .minimumScaleFactor(minimumScaleFactor)
        }
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
    }

    private func hero(at size: CGFloat) -> some View {
        Group {
            if word.containsCJK {
                // Latin-only variable fonts can't set CJK; match the hero weight
                // with the system face (which cascades to Hiragino).
                Text(word)
                    .font(.system(size: size, weight: .semibold))
            } else if LFWVariableFont.isRegistered(typeface.family) {
                Text(word)
                    .font(.lfwVariable(typeface.family, size: size, axes: axes(at: size)))
            } else {
                Text(word)
                    .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
            }
        }
        .foregroundStyle(color)
        .background(
            Circle()
                .fill(glow.opacity(0.16))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 30)
        )
    }

    /// Variable-font axes: rest weight, plus optical size when the face supports it.
    private func axes(at size: CGFloat) -> [Int: CGFloat] {
        var axes: [Int: CGFloat] = [LFWVariableFont.weight: 560]
        if typeface.hasOpticalSize {
            axes[LFWVariableFont.opticalSize] = min(max(size, 9), 144)
        }
        return axes
    }
}
