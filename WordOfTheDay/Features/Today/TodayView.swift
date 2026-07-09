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
    /// Bumped on each mark tap to fire selection haptics — tactile confirmation
    /// the tap registered even when the day's word doesn't change.
    @State private var markFeedback = 0

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
        // The mark buttons nudge the difficulty band; when the band actually
        // moves, today's word swaps. But a mark on a word below your band (or at
        // the top band) leaves the band — and the word — unchanged, so without an
        // explicit answered state the tap looks like it did nothing. Reflect the
        // recorded mark here so every tap is acknowledged either way.
        let mark = model.markState(for: word.id)
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    markFeedback += 1
                    model.mark(word, known: false)
                } label: {
                    markLabel("Still learning", systemImage: "arrow.down", selected: mark == false)
                }
                .buttonStyle(.themedCTA(palette: palette, filled: mark == false))

                Button {
                    markFeedback += 1
                    model.mark(word, known: true)
                } label: {
                    markLabel("I know this", systemImage: "checkmark", selected: mark == true)
                }
                // Primary emphasis defaults to "I know this" until a choice is
                // made, then follows the chosen answer.
                .buttonStyle(.themedCTA(palette: palette, filled: mark != false))
            }

            // Always present (fixed height, no layout jump) so a mark that
            // doesn't change the word is still visibly acknowledged.
            Text(confirmation(for: mark))
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 12))
                .foregroundStyle(mark == nil ? palette.secondaryText : palette.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.2), value: mark)
        }
        .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
        .sensoryFeedback(.selection, trigger: markFeedback)
    }

    private func markLabel(_ title: String, systemImage: String, selected: Bool) -> some View {
        // A filled check-circle marks the chosen answer; combined with the caption
        // it reads as "this is what you picked" without hiding the other option.
        Label(title, systemImage: selected ? "checkmark.circle.fill" : systemImage)
    }

    private func confirmation(for mark: Bool?) -> String {
        switch mark {
        case .some(true):  return "Marked as known — we'll surface rarer words."
        case .some(false): return "Marked as still learning — we'll keep it in reach."
        case .none:        return "Did you already know this word?"
        }
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
