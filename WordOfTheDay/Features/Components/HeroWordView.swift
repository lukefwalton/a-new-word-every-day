import SwiftUI
import LFWDesignSystem

/// The day's word, rendered large in the chosen variable typeface. When the
/// variable font is bundled the weight axis animates up on appear so the word
/// "settles in"; otherwise it falls back to a static system face. Used by both
/// the Today screen and the onboarding cards.
struct HeroWordView: View {
    let word: String
    let typeface: LFWTypeface
    let color: Color
    var size: CGFloat = 56
    var animateOnAppear: Bool = true

    @State private var weightAxis: CGFloat = 280

    private var opticalAxes: [Int: CGFloat] {
        typeface.hasOpticalSize ? [LFWVariableFont.opticalSize: min(max(size, 9), 144)] : [:]
    }

    var body: some View {
        Group {
            if LFWVariableFont.isRegistered(typeface.family) {
                Text(word)
                    .lfwVariableAxis(weightAxis, name: typeface.family, size: size,
                                     tag: LFWVariableFont.weight, staticAxes: opticalAxes)
                    .onAppear {
                        guard animateOnAppear else { weightAxis = 560; return }
                        withAnimation(.easeOut(duration: 0.9)) { weightAxis = 560 }
                    }
            } else {
                Text(word)
                    .font(LFWTypography.font(.heroWord, typeface: typeface, size: size))
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .accessibilityAddTraits(.isHeader)
    }
}
