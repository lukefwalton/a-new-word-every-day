import SwiftUI
import LFWDesignSystem

/// The in-app mirror of the widget: today's word — one page per enabled
/// language — large, in the chosen variable font and palette, with star + a
/// quiet "did you know it?" mark that nudges that language's difficulty band.
struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    /// The language page in view. Keyed by language (not word id) so a mark that
    /// swaps the day's word re-renders in place instead of resetting the pager.
    @State private var pagedLanguage: Language = .english

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    /// A deep-linked/widget-focused word, which takes over the whole screen.
    private var focusedWord: Word? {
        model.focusedWordID.flatMap { model.service.word(id: $0) }
    }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            if let focused = focusedWord {
                content(focused)
            } else if model.todaysWords.isEmpty {
                emptyState
            } else if model.todaysWords.count == 1 {
                content(model.todaysWords[0])
            } else {
                // One page per language; the dots double as the "there's more" cue.
                TabView(selection: $pagedLanguage) {
                    ForEach(model.todaysWords, id: \.language) { word in
                        content(word)
                            .tag(word.language)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
            }
        }
    }

    private func eyebrow(_ word: Word) -> String {
        if model.focusedWordID != nil { return "SAVED WORD" }
        guard model.enabledLanguages.count > 1 else { return "WORD OF THE DAY" }
        return "WORD OF THE DAY · \(word.language.displayName.uppercased())"
    }

    private func content(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text(eyebrow(word))
                    .font(LFWTypography.font(.eyebrow, typeface: typeface))
                    .kerning(2)
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                // Viewing a saved word is transient: offer an explicit way back to
                // the actual daily word rather than persisting the override.
                if model.focusedWordID != nil {
                    Button {
                        model.focusedWordID = nil
                    } label: {
                        Label("Today", systemImage: "arrow.uturn.backward")
                            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 13))
                    }
                    .tint(palette.accent)
                }
                starButton(word)
            }

            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText, size: 60)

            if let reading = word.displayReading {
                Text(reading)
                    .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 20))
                    .foregroundStyle(palette.secondaryText)
            }

            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface))
                .foregroundStyle(palette.accent)

            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

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
            .buttonStyle(.themedCTA(palette: palette, filled: false))

            Button {
                model.mark(word, known: true)
            } label: {
                Label("I know this", systemImage: "checkmark")
            }
            .buttonStyle(.themedCTA(palette: palette, filled: true))
        }
        .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
    }

    private var emptyState: some View {
        // Shared family empty state instead of a system ContentUnavailableView stub;
        // the glyph takes the active palette's accent so it still themes.
        LFWEmptyState(
            symbol: "character.book.closed",
            title: "No words yet",
            message: "The word list couldn't be loaded. Reopen the app to try again.",
            accent: palette.accent
        )
    }
}
