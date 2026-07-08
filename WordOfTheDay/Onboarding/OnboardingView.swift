import SwiftUI
import LFWDesignSystem

/// Four phases: a short explainer pager (family `LFWOnboardingScaffold` look), a
/// language multi-select, then per chosen language either the swipe deck that
/// calibrates the difficulty band or a self-assessment level picker ("Skip — I
/// know my level"). Kept in one dark themed surface. The pager and the deck are
/// separated so horizontal paging never fights the deck's horizontal drag.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var phase: Phase = .intro
    @State private var page = 0
    @State private var deck: [Word] = []
    /// Languages picked on the selection screen, in `Language.allCases` order.
    @State private var selected: Set<Language> = [.english]
    /// Languages still waiting for a level (calibration or self-assessment).
    @State private var pending: [Language] = []
    /// Each completed language's starting band.
    @State private var bands: [Language: Int] = [:]
    /// The self-assessment picker's current choice.
    @State private var pickedLevel = 2

    enum Phase: Equatable {
        case intro
        case languages
        case calibrate(Language)
        case selfAssess(Language)
    }

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            switch phase {
            case .intro:                    intro
            case .languages:                languagePicker
            case .calibrate(let language):  calibrate(language)
            case .selfAssess(let language): selfAssess(language)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Intro pager

    private var intro: some View {
        ZStack(alignment: .top) {
            TabView(selection: $page) {
                introPage(
                    symbol: "character.book.closed.fill",
                    eyebrow: "One word a day",
                    title: "Grow a sharper\nvocabulary, daily.",
                    message: "Each day, one elevated word — on your Home Screen and here. Beautiful type, your colors.",
                    cta: "Next", action: { advance(to: 1) }
                ).tag(0)

                introPage(
                    symbol: "lock.fill",
                    eyebrow: "Yours alone",
                    title: "Free. No login.\nNothing leaves your phone.",
                    message: "No account, no servers, no tracking, no analytics. Your stars and settings stay on this device.",
                    cta: "Next", action: { advance(to: 2) }
                ).tag(1)

                introPage(
                    symbol: "globe.asia.australia.fill",
                    eyebrow: "Your languages",
                    title: "English, Japanese —\nor both at once.",
                    message: "Pick the languages you're learning. Each gets its own daily word, its own level, its own widget.",
                    cta: "Choose languages", action: { withAnimation(.easeInOut(duration: 0.35)) { phase = .languages } }
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            LFWPageDots(count: 3, index: page)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
    }

    private func introPage(symbol: String, eyebrow: String, title: String,
                           message: String, cta: String, action: @escaping () -> Void) -> some View {
        LFWOnboardingScaffold(symbol: symbol, eyebrow: eyebrow, title: title) {
            LFWOnboardingMessage(message)
        } footer: {
            Button(cta, action: action)
                .buttonStyle(.lfwCTA)
        }
    }

    // MARK: Language selection

    private var languagePicker: some View {
        LFWOnboardingScaffold(symbol: "globe.asia.australia.fill",
                              eyebrow: "What are you learning?",
                              title: "Pick your\nlanguages.") {
            VStack(spacing: 12) {
                ForEach(Language.allCases) { language in
                    languageRow(language)
                }
                Text("You can add or remove languages any time in Settings.")
                    .font(LFWTypography.font(.uiBody, typeface: typeface, size: 13))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 4)
            }
        } footer: {
            Button("Continue") { startLevelFlow() }
                .buttonStyle(.lfwCTA)
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.5 : 1)
        }
    }

    private func languageRow(_ language: Language) -> some View {
        let isOn = selected.contains(language)
        return Button {
            if isOn { selected.remove(language) } else { selected.insert(language) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 19))
                        .foregroundStyle(palette.primaryText)
                    if language.nativeName != language.displayName {
                        Text(language.nativeName)
                            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 14))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isOn ? palette.accent : palette.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .strokeBorder(isOn ? palette.accent.opacity(0.7) : palette.primaryText.opacity(0.12),
                                  lineWidth: isOn ? 1.5 : 1)
            )
        }
        .accessibilityLabel("\(language.displayName)\(isOn ? ", selected" : "")")
    }

    // MARK: Calibrate (per language)

    private func calibrate(_ language: Language) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(selected.count > 1
                     ? "DO YOU KNOW THIS \(language.displayName.uppercased()) WORD?"
                     : "DO YOU KNOW THIS WORD?")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface))
                    .kerning(2)
                    .foregroundStyle(palette.accent)
                Text("Swipe right if you know it, left if it's new.")
                    .font(LFWTypography.font(.uiBody, typeface: typeface, size: 14))
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(.top, 24)

            Spacer(minLength: 12)

            SwipeDeck(words: deck, typeface: typeface, palette: palette) { answers in
                let mapped = answers.map { DifficultyModel.Answer(band: $0.word.band, known: $0.known) }
                finishLanguage(language, band: model.calibratedBand(from: mapped))
            }
            // Rebuild the deck view per language so a second language starts fresh.
            .id(language)

            Spacer(minLength: 12)

            Button("Skip — I know my level") {
                pickedLevel = 2
                withAnimation(.easeInOut(duration: 0.35)) { phase = .selfAssess(language) }
            }
            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
            .foregroundStyle(palette.secondaryText)
            .padding(.bottom, 28)
        }
    }

    // MARK: Self-assessment (per language)

    private func selfAssess(_ language: Language) -> some View {
        LFWOnboardingScaffold(symbol: "slider.horizontal.3",
                              eyebrow: language.displayName,
                              title: "Where would you\nplace yourself?") {
            VStack(spacing: 10) {
                ForEach(1...5, id: \.self) { band in
                    levelRow(language, band: band)
                }
            }
        } footer: {
            VStack(spacing: 14) {
                Button("Continue") { finishLanguage(language, band: pickedLevel) }
                    .buttonStyle(.lfwCTA)
                Button("Back to swiping") {
                    withAnimation(.easeInOut(duration: 0.35)) { phase = .calibrate(language) }
                }
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
                .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func levelRow(_ language: Language, band: Int) -> some View {
        let isOn = pickedLevel == band
        return Button {
            pickedLevel = band
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.levelName(forBand: band))
                        .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 17))
                        .foregroundStyle(palette.primaryText)
                    Text(language.levelDescriptions[band - 1])
                        .font(LFWTypography.font(.uiBody, typeface: typeface, size: 13))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .strokeBorder(isOn ? palette.accent.opacity(0.7) : palette.primaryText.opacity(0.12),
                                  lineWidth: isOn ? 1.5 : 1)
            )
        }
        .accessibilityLabel("\(language.levelName(forBand: band)) — \(language.levelDescriptions[band - 1])")
    }

    // MARK: Navigation

    private func advance(to target: Int) {
        withAnimation(.easeInOut) { page = target }
    }

    /// Kick off the per-language level flow for the picked languages.
    private func startLevelFlow() {
        let ordered = Language.allCases.filter(selected.contains)
        guard !ordered.isEmpty else { return }
        pending = ordered
        bands = [:]
        nextLanguage()
    }

    /// Move to the next pending language's calibration, or finish onboarding.
    private func nextLanguage() {
        guard let language = pending.first else {
            let ordered = Language.allCases.filter(selected.contains)
            model.completeOnboarding(languages: ordered, bands: bands)
            return
        }
        deck = model.calibrationDeck(for: language)
        guard !deck.isEmpty else {
            // No corpus to calibrate on — fall back to a gentle middle start.
            finishLanguage(language, band: 2)
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { phase = .calibrate(language) }
    }

    private func finishLanguage(_ language: Language, band: Int) {
        bands[language] = band
        pending.removeAll { $0 == language }
        nextLanguage()
    }
}
