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
    private let engine: ReviewEngine

    enum Tab: Hashable { case today, practice, settings }

    @Published var theme: LFWThemeConfig
    @Published var selectedTab: Tab = .today
    @Published private(set) var band: Int
    @Published private(set) var onboardingComplete: Bool
    @Published private(set) var starredIDs: [Int]
    @Published private(set) var today: Word?
    /// Number of starred words due to study now — drives the Practice tab's
    /// (secondary, opt-in) Study affordance.
    @Published private(set) var dueCount: Int = 0
    @Published private(set) var widgetPreferences: WidgetPreferences = .default
    /// Set when a deep link (or the widget) asks to focus a specific word.
    @Published var focusedWordID: Int?

    init(service: DailyWordService, store: SharedStore = .shared, engine: ReviewEngine = ReviewEngine()) {
        #if DEBUG
        Self.applyUITestLaunchOverrides(to: store)
        #endif
        self.service = service
        self.store = store
        self.engine = engine
        self.theme = store.theme
        self.band = store.band
        self.onboardingComplete = store.onboardingComplete
        self.starredIDs = store.starredIDs
        self.today = service.todaysWord(store: store)
        self.widgetPreferences = store.widgetPreferences
        recomputeDue()
    }

    var corpusIsEmpty: Bool { service.corpus.words.isEmpty }

    func refreshFromStore() {
        theme = store.theme
        onboardingComplete = store.onboardingComplete
        starredIDs = store.starredIDs
        band = store.band
        widgetPreferences = store.widgetPreferences
        today = service.todaysWord(store: store)
        recomputeDue()
    }

    // MARK: Theme

    /// Apply a theme. `reloadWidget` is false for continuous input (the accent
    /// slider) so we don't hammer `reloadAllTimelines()` on every step — the
    /// caller reloads once when the interaction ends via `reloadWidget()`.
    func setTheme(_ config: LFWThemeConfig, reloadWidget: Bool = true) {
        theme = config
        store.theme = config
        if reloadWidget { WidgetReloader.reload() }
    }

    /// Force a widget refresh for the current theme (used when a debounced
    /// interaction, like the accent slider, finishes).
    func reloadWidget() {
        WidgetReloader.reload()
    }

    func setWidgetPreferences(_ preferences: WidgetPreferences) {
        widgetPreferences = preferences
        store.widgetPreferences = preferences
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
        recomputeDue()
        WidgetReloader.reload()
    }

    var starredWords: [Word] { service.starredWords(store: store) }

    func unstar(_ ids: [Int]) {
        for id in ids where store.isStarred(id) { store.toggleStar(id) }
        store.removeReviewStates(ids)
        starredIDs = store.starredIDs
        recomputeDue()
        WidgetReloader.reload()
    }

    // MARK: Review (in-app study — the lightweight Anki behind the widget)

    /// Words ready to study now: starred words whose schedule is due, or that have
    /// never been reviewed. Due-soonest first; never-reviewed words sort last, so a
    /// session clears pending reviews before introducing brand-new cards.
    func dueWords(now: Date = Date()) -> [Word] {
        let states = store.reviewStates
        return service.starredWords(store: store)
            .filter { engine.isDue(states[$0.id], now: now) }
            .sorted { lhs, rhs in
                switch (states[lhs.id]?.due, states[rhs.id]?.due) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true     // scheduled words before brand-new
                case (nil, _?):    return false
                case (nil, nil):   return false
                }
            }
    }

    /// Record a recall grade for a word and persist its new FSRS schedule.
    func grade(_ word: Word, _ grade: ReviewGrade, now: Date = Date()) {
        var states = store.reviewStates
        states[word.id] = engine.grade(states[word.id], grade, now: now)
        store.reviewStates = states
        recomputeDue(now: now)
    }

    /// Refresh the published due count that drives the Practice tab's Study affordance.
    func recomputeDue(now: Date = Date()) {
        dueCount = dueWords(now: now).count
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

    /// Open a saved word on the Today tab. Sets the tab explicitly (not just the
    /// focused id) so reselecting the *same* word still navigates — a value-only
    /// `onChange` would miss an unchanged id.
    func openWord(_ id: Int) {
        focusedWordID = id
        selectedTab = .today
    }

    func handle(url: URL) {
        guard url.scheme == "wordoftheday" else { return }
        if url.host == "word", let id = Int(url.lastPathComponent) {
            openWord(id)
        }
    }

    #if DEBUG
    /// UI-test launch flags. `-UITestResetOnboarding` clears persisted state so
    /// each test run starts from the onboarding gate; `-UITestSkipOnboarding`
    /// jumps straight to the tab shell (after reset).
    private static func applyUITestLaunchOverrides(to store: SharedStore) {
        let args = Set(ProcessInfo.processInfo.arguments)
        guard args.contains("-UITestResetOnboarding") || args.contains("-UITestSkipOnboarding") else { return }
        let suite = AppGroup.identifier
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        if args.contains("-UITestSkipOnboarding") {
            store.onboardingComplete = true
            store.band = 2
        }
    }
    #endif
}
