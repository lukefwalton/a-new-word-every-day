import SwiftUI
import LFWDesignSystem

/// A lightweight, opt-in study session over the words due now — the "Anki behind
/// the widget", kept deliberately small: one card at a time, tap to reveal the
/// definition, grade Again/Hard/Good/Easy, and FSRS schedules the next review. No
/// decks, no editing. Reached from the Practice tab; the daily word + widget stay
/// the primary surface.
struct ReviewSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Snapshotted once on appear so grading a word (which reschedules it out of
    /// "due") doesn't reshuffle the deck mid-session. `ReviewQueue` re-queues a
    /// failed card so it returns later in this same session.
    @State private var queue = ReviewQueue([])
    @State private var revealed = false

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            VStack(spacing: 0) {
                header
                if let word = queue.current {
                    card(word)
                } else {
                    finished
                }
            }
            .padding(24)
        }
        .onAppear { if queue.words.isEmpty { queue = ReviewQueue(model.dueWords()) } }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            .accessibilityLabel("Close study session")
            Spacer()
            if queue.current != nil {
                Text("\(queue.position.current) of \(queue.position.total)")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface))
                    .kerning(1.5)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            // Invisible twin of the close button so the counter stays centred.
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func card(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("WORD")
                .font(LFWTypography.font(.eyebrow, typeface: typeface))
                .kerning(2)
                .foregroundStyle(palette.accent)

            // `.id(word.id)` rebuilds the hero per card so its reveal animation replays.
            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText, size: 56)
                .id(word.id)

            if revealed {
                Text(word.partOfSpeechLabel)
                    .font(LFWTypography.font(.partOfSpeech, typeface: typeface))
                    .foregroundStyle(palette.accent)
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap to reveal the definition")
                    .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            if revealed {
                gradeButtons(word)
            } else {
                Button { reveal() } label: {
                    Text("Reveal").frame(maxWidth: .infinity)
                }
                .buttonStyle(.themedCTA(palette: palette, filled: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { if !revealed { reveal() } }
        .animation(.easeInOut(duration: 0.2), value: revealed)
    }

    private func gradeButtons(_ word: Word) -> some View {
        HStack(spacing: 10) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button { commit(grade, for: word) } label: {
                    Text(grade.label).frame(maxWidth: .infinity)
                }
                .buttonStyle(.themedCTA(palette: palette, filled: grade == .good))
                .accessibilityLabel("\(grade.label) — grade your recall")
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.accent)
            Text("All caught up")
                .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 24))
                .foregroundStyle(palette.primaryText)
            Text("You've reviewed every word that was due.")
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button { dismiss() } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.themedCTA(palette: palette, filled: true))
        }
        .frame(maxWidth: .infinity)
    }

    private func reveal() { revealed = true }

    private func commit(_ grade: ReviewGrade, for word: Word) {
        model.grade(word, grade)
        queue.advance(grade: grade)
        revealed = false
    }
}

private extension ReviewGrade {
    var label: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
}
