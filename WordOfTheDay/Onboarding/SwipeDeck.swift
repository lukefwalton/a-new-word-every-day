import SwiftUI
import LFWDesignSystem

/// A hand-rolled, two-way Tinder deck. ~150 lines of `DragGesture` + `offset` +
/// `rotationEffect` — chosen over a dependency because no SwiftUI-native library
/// offers maintained + 2-way overlays + undo together, and the mechanism is this
/// small. Right = "I know it", left = "new to me". Buttons drive the same path,
/// and undo restores the last card.
struct SwipeDeck: View {
    let words: [Word]
    let typeface: LFWTypeface
    let palette: LFWPaletteColors
    /// Called once the deck is empty, with one answer per card in swipe order.
    let onComplete: ([Answer]) -> Void

    struct Answer: Equatable {
        let word: Word
        let known: Bool
    }

    /// Cards still to answer; `last` is the top (cheap to pop).
    @State private var remaining: [Word]
    @State private var answers: [Answer] = []
    @State private var drag: CGSize = .zero
    /// True while the top card is flying off — input is locked so a fast second
    /// tap/swipe can't record a duplicate answer for the same word.
    @State private var isCommitting = false

    private let threshold: CGFloat = 110

    init(words: [Word], typeface: LFWTypeface, palette: LFWPaletteColors,
         onComplete: @escaping ([Answer]) -> Void) {
        self.words = words
        self.typeface = typeface
        self.palette = palette
        self.onComplete = onComplete
        _remaining = State(initialValue: words.reversed())
    }

    var body: some View {
        VStack(spacing: 24) {
            progress
            ZStack {
                ForEach(Array(remaining.enumerated()), id: \.element.id) { index, word in
                    let depth = remaining.count - 1 - index // 0 == top card
                    if depth < 3 {
                        card(word, isTop: depth == 0)
                            .scaleEffect(1 - CGFloat(depth) * 0.04)
                            .offset(y: CGFloat(depth) * 12)
                            .zIndex(Double(index))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(!isCommitting)
            controls
                .disabled(isCommitting)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Card

    private func card(_ word: Word, isTop: Bool) -> some View {
        VStack(spacing: 16) {
            Text(word.partOfSpeechLabel.uppercased())
                .font(LFWTypography.font(.eyebrow, typeface: typeface))
                .kerning(2)
                .foregroundStyle(palette.accent)
            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText,
                         size: 40, animateOnAppear: false)
            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface, size: 17))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                .fill(palette.backgroundTop.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .strokeBorder(palette.primaryText.opacity(0.12), lineWidth: 1))
        )
        .overlay(alignment: .topLeading) { if isTop { verdictBadge(known: true) } }
        .overlay(alignment: .topTrailing) { if isTop { verdictBadge(known: false) } }
        .offset(isTop ? drag : .zero)
        .rotationEffect(.degrees(isTop ? Double(drag.width / 22) : 0))
        .gesture(isTop ? dragGesture(for: word) : nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: drag == .zero)
    }

    /// KNOW (leading, green-ish) / NEW (trailing, accent) badges that fade in with
    /// the drag. "Know" shows when dragging right, "New" when dragging left.
    private func verdictBadge(known: Bool) -> some View {
        let active = known ? drag.width > 0 : drag.width < 0
        let opacity = active ? min(abs(drag.width) / threshold, 1) : 0
        return Text(known ? "KNOW" : "NEW")
            .font(LFWTypography.font(.eyebrow, typeface: typeface, size: 16))
            .kerning(2)
            .foregroundStyle(known ? LFWColors.kelp : palette.accent)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: LFWRadius.chip)
                .strokeBorder(known ? LFWColors.kelp : palette.accent, lineWidth: 2))
            .padding(18)
            .opacity(opacity)
            .rotationEffect(.degrees(known ? -12 : 12))
    }

    // MARK: Gesture + commit

    private func dragGesture(for word: Word) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width > threshold { commit(word, known: true) }
                else if value.translation.width < -threshold { commit(word, known: false) }
                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = .zero } }
            }
    }

    private func commit(_ word: Word, known: Bool) {
        guard !isCommitting else { return }
        isCommitting = true
        withAnimation(.easeOut(duration: 0.22)) {
            drag = CGSize(width: known ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            remaining.removeAll { $0.id == word.id }
            answers.append(Answer(word: word, known: known))
            drag = .zero
            isCommitting = false
            if remaining.isEmpty { onComplete(answers) }
        }
    }

    private func undo() {
        guard let last = answers.popLast() else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            remaining.append(last.word)
        }
    }

    // MARK: Chrome

    private var progress: some View {
        let done = words.count - remaining.count
        return Text("\(done) of \(words.count)")
            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 14))
            .foregroundStyle(palette.secondaryText)
            .monospacedDigit()
    }

    private var controls: some View {
        HStack(spacing: 20) {
            controlButton(symbol: "xmark", tint: palette.accent, label: "New to me") {
                if let top = remaining.last { commit(top, known: false) }
            }
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(palette.surface))
            }
            .disabled(answers.isEmpty)
            .opacity(answers.isEmpty ? 0.4 : 1)
            controlButton(symbol: "checkmark", tint: LFWColors.kelp, label: "I know it") {
                if let top = remaining.last { commit(top, known: true) }
            }
        }
    }

    private func controlButton(symbol: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(palette.surface))
                .overlay(Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5))
        }
        .accessibilityLabel(label)
    }
}
