import SwiftUI
import LFWDesignSystem

/// The app's single source of UI state, layered over `SharedStore` (the App Group
/// store the widget also reads). Every mutation writes through to the store and
/// reloads the widget so the two stay in lockstep.
@MainActor
final class AppModel: ObservableObject {
    let service: DailyWordService
    let store: SharedStore
    private let difficulty = DifficultyModel()

    @Published var theme: LFWThemeConfig
    @Published private(set) var band: Int
    @Published private(set) var onboardingComplete: Bool
    @Published private(set) var starredIDs: [Int]
    @Published private(set) var today: Word?
    /// Set when a deep link (or the widget) asks to focus a specific word.
    @Published var focusedWordID: Int?

    init(service: DailyWordService, store: SharedStore = .shared) {
        self.service = service
        self.store = store
        self.theme = store.theme
        self.band = store.band
        self.onboardingComplete = store.onboardingComplete
        self.starredIDs = store.starredIDs
        self.today = service.todaysWord(store: store)
    }

    var corpusIsEmpty: Bool { service.corpus.words.isEmpty }

    func refreshFromStore() {
        starredIDs = store.starredIDs
        band = store.band
        today = service.todaysWord(store: store)
    }

    // MARK: Theme

    func setTheme(_ config: LFWThemeConfig) {
        theme = config
        store.theme = config
        WidgetReloader.reload()
    }

    // MARK: Difficulty

    func setBand(_ value: Int) {
        let clamped = min(max(value, 1), difficulty.maxBand)
        band = clamped
        store.band = clamped
        today = service.todaysWord(store: store)
        WidgetReloader.reload()
    }

    // MARK: Onboarding

    func completeOnboarding(answers: [DifficultyModel.Answer]) {
        let calibrated = difficulty.calibratedBand(from: answers)
        store.band = calibrated
        store.onboardingComplete = true
        band = calibrated
        onboardingComplete = true
        today = service.todaysWord(store: store)
        WidgetReloader.reload()
    }

    /// The deck of words the swipe step calibrates on.
    func calibrationDeck() -> [Word] {
        service.calibrationSample(salt: store.installSalt)
    }

    // MARK: Stars

    func isStarred(_ id: Int) -> Bool { starredIDs.contains(id) }

    func toggleStar(_ id: Int) {
        store.toggleStar(id)
        starredIDs = store.starredIDs
        WidgetReloader.reload()
    }

    var starredWords: [Word] { service.starredWords(store: store) }

    func unstar(_ ids: [Int]) {
        for id in ids where store.isStarred(id) { store.toggleStar(id) }
        starredIDs = store.starredIDs
        WidgetReloader.reload()
    }

    // MARK: In-app word marking (nudges the band)

    func mark(_ word: Word, known: Bool) {
        var marks = store.difficultyMarks
        // Idempotent: only the *first* (or a changed) mark for a word nudges the
        // band. Tapping the same answer repeatedly must not ratchet difficulty.
        guard marks[word.id] != known else { return }
        marks[word.id] = known
        store.difficultyMarks = marks
        setBand(difficulty.adjusted(band: band, markedKnown: known, wordBand: word.band))
    }

    // MARK: Deep links

    func handle(url: URL) {
        guard url.scheme == "wordoftheday" else { return }
        if url.host == "word", let id = Int(url.lastPathComponent) {
            focusedWordID = id
        }
    }
}
