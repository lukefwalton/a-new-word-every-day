import SwiftUI
import LFWDesignSystem

/// Two phases: a short explainer pager (family `LFWOnboardingScaffold` look), then
/// the swipe deck that calibrates the difficulty band. Kept in one dark themed
/// surface. The pager and the deck are separated so horizontal paging never
/// fights the deck's horizontal drag.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var phase: Phase = .intro
    @State private var page = 0
    @State private var deck: [Word] = []

    enum Phase { case intro, calibrate }

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            switch phase {
            case .intro:     intro
            case .calibrate: calibrate
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
                    symbol: "hand.draw.fill",
                    eyebrow: "Find your level",
                    title: "Swipe to teach it\nwhat you know.",
                    message: "Swipe right on words you know, left on the ones you don't. We'll pitch each day's word right at your edge.",
                    cta: "Start", action: startCalibration
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

    // MARK: Calibrate

    private var calibrate: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("DO YOU KNOW THIS WORD?")
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
                model.completeOnboarding(answers: mapped)
            }

            Spacer(minLength: 12)

            Button("Skip — start in the middle") {
                model.completeOnboarding(answers: [])
            }
            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
            .foregroundStyle(palette.secondaryText)
            .padding(.bottom, 28)
        }
    }

    // MARK: Navigation

    private func advance(to target: Int) {
        withAnimation(.easeInOut) { page = target }
    }

    private func startCalibration() {
        deck = model.calibrationDeck()
        guard !deck.isEmpty else {
            model.completeOnboarding(answers: [])
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) { phase = .calibrate }
    }
}
