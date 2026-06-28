import SwiftUI
import LFWDesignSystem

/// The in-app mirror of the widget: today's word, large, in the chosen variable
/// font and palette, with star + a quiet "did you know it?" mark that nudges the
/// difficulty band.
struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    /// The word to show: a deep-linked/widget-focused one if set, else today's.
    private var word: Word? {
        if let id = model.focusedWordID, let w = model.service.word(id: id) { return w }
        return model.today
    }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            if let word {
                content(word)
            } else {
                emptyState
            }
        }
    }

    private func content(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(model.focusedWordID == nil ? "WORD OF THE DAY" : "SAVED WORD")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface))
                    .kerning(2)
                    .foregroundStyle(palette.accent)
                Spacer()
                starButton(word)
            }

            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText, size: 60)

            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface))
                .foregroundStyle(palette.accent)

            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !word.example.isEmpty {
                Text("“\(word.example)”")
                    .font(LFWTypography.font(.example, typeface: typeface))
                    .italic()
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            knowControls(word)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func starButton(_ word: Word) -> some View {
        Button {
            model.toggleStar(word.id)
        } label: {
            Image(systemName: model.isStarred(word.id) ? "star.fill" : "star")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(model.isStarred(word.id) ? palette.accent : palette.secondaryText)
        }
        .accessibilityLabel(model.isStarred(word.id) ? "Remove from practice list" : "Save to practice list")
    }

    private func knowControls(_ word: Word) -> some View {
        HStack(spacing: 12) {
            Button {
                model.mark(word, known: false)
            } label: {
                Label("Still learning", systemImage: "arrow.down")
            }
            .buttonStyle(.lfwCTA(filled: false))

            Button {
                model.mark(word, known: true)
            } label: {
                Label("I know this", systemImage: "checkmark")
            }
            .buttonStyle(.lfwCTA(filled: true))
        }
        .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No words yet", systemImage: "character.book.closed")
        } description: {
            Text("The word list couldn't be loaded. Reopen the app to try again.")
        }
    }
}
