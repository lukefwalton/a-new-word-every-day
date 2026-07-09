import SwiftUI
import LFWDesignSystem

/// The in-app mirror of the widget: today's word — one page per enabled
/// language — large, in the chosen variable font and palette, with star + a
/// "did you know it?" mark that nudges that language's difficulty band and
/// advances to a fresh word from your level (so a word you already know is never
/// a dead end). The widget keeps showing the canonical word of the day; this
/// "keep going" flow is in-app only.
struct TodayView: View {
    @EnvironmentObject private var model: AppModel
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
            } else if model.displayWords.isEmpty {
                emptyState
            } else if model.displayWords.count == 1 {
                content(model.displayWords[0])
            } else {
                // One page per language; the dots double as the "there's more" cue.
                // Selection lives on the model so a widget tap can front the tapped
                // language (and manual swipes keep it in sync).
                TabView(selection: $model.todayLanguage) {
                    ForEach(model.displayWords, id: \.language) { word in
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
        let stem = model.isExploring(word.language) ? "ANOTHER WORD" : "WORD OF THE DAY"
        guard model.enabledLanguages.count > 1 else { return stem }
        return "\(stem) · \(word.language.displayName.uppercased())"
    }

    /// Shown when Today isn't on the canonical daily word: a deep-linked saved
    /// word, or a word reached via the in-app "keep going" flow. Both return to
    /// today's word.
    @ViewBuilder
    private func backToTodayButton(_ word: Word) -> some View {
        if model.focusedWordID != nil {
            todayButton { model.focusedWordID = nil }
        } else if model.isExploring(word.language) {
            todayButton { model.backToToday(word.language) }
        }
    }

    private func todayButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Today", systemImage: "arrow.uturn.backward")
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 13))
        }
        .tint(palette.accent)
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
                // Viewing a saved or "keep going" word is transient: offer an
                // explicit way back to the actual daily word.
                backToTodayButton(word)
                speakButton(word)
                starButton(word)
            }

            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText, size: 60)

            if let reading = word.displayReading {
                Text(reading)
                    .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 20))
                    .foregroundStyle(palette.secondaryText)
            }

            // Rōmaji so learners who don't read kana can still say the word.
            if let romaji = word.romaji {
                Text(romaji)
                    .font(LFWTypography.font(.uiBody, typeface: typeface, size: 16))
                    .foregroundStyle(palette.secondaryText.opacity(0.85))
            }

            Text(word.partOfSpeechLabel)
                .font(LFWTypography.font(.partOfSpeech, typeface: typeface))
                .foregroundStyle(palette.accent)

            Text(word.definition)
                .font(LFWTypography.font(.definition, typeface: typeface))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // The daily / "keep going" flow advances to a fresh word on each
            // assessment; the deep-linked saved-word view just records the mark.
            knowControls(word, advances: model.focusedWordID == nil)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func speakButton(_ word: Word) -> some View {
        let speaking = model.speakingWordID == word.id
        return Button {
            model.speak(word)
        } label: {
            Image(systemName: speaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(speaking ? palette.accent : palette.secondaryText)
        }
        .accessibilityLabel(speaking ? "Stop pronunciation" : "Pronounce \(word.word)")
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

    private func knowControls(_ word: Word, advances: Bool) -> some View {
        // In the daily / "keep going" flow, assessing advances to a fresh word from
        // your band, so a word you already know is never a dead end. The recorded
        // mark also drives an answered state, which is what shows through at the
        // edges: the caught-up case, the saved-word view, or returning to an
        // already-marked daily word — where the word doesn't advance.
        let mark = model.markState(for: word.id)
        let caughtUp = advances && model.isCaughtUp(word.language)
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    recordAssessment(word, known: false, advances: advances)
                } label: {
                    markLabel("New to me", systemImage: "arrow.down", selected: mark == false)
                }
                .buttonStyle(.themedCTA(palette: palette, filled: mark == false))

                Button {
                    recordAssessment(word, known: true, advances: advances)
                } label: {
                    markLabel("I know this", systemImage: "checkmark", selected: mark == true)
                }
                // Primary emphasis defaults to "I know this" until a choice is
                // made, then follows the chosen answer.
                .buttonStyle(.themedCTA(palette: palette, filled: mark != false))
            }

            // Always present (fixed height, no layout jump) so every tap is
            // acknowledged — the next word, or a note when the band is exhausted.
            Text(caption(mark: mark, caughtUp: caughtUp, advances: advances))
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 12))
                .foregroundStyle(caughtUp || mark != nil ? palette.accent : palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: mark)
                .animation(.easeInOut(duration: 0.2), value: caughtUp)
        }
        .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
        .sensoryFeedback(.selection, trigger: markFeedback)
    }

    private func recordAssessment(_ word: Word, known: Bool, advances: Bool) {
        markFeedback += 1
        if advances {
            model.assess(word, known: known)
        } else {
            model.mark(word, known: known)
        }
    }

    private func markLabel(_ title: String, systemImage: String, selected: Bool) -> some View {
        // A filled check-circle marks the chosen answer; combined with the caption
        // it reads as "this is what you picked" without hiding the other option.
        Label(title, systemImage: selected ? "checkmark.circle.fill" : systemImage)
    }

    private func caption(mark: Bool?, caughtUp: Bool, advances: Bool) -> String {
        if caughtUp {
            return "That's every word at your level for now — check back tomorrow, or raise your level in Settings."
        }
        switch mark {
        case .some(true):  return "Marked as known — we'll surface rarer words."
        case .some(false): return "New one for you — we'll keep it in reach."
        case .none:
            return advances
                ? "Know it or not — either way we'll show you another."
                : "Did you already know this word?"
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
