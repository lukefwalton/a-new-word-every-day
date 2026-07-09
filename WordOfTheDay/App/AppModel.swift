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
    @Published private(set) var enabledLanguages: [Language]
    @Published private(set) var bands: [Language: Int]
    @Published private(set) var onboardingComplete: Bool
    @Published private(set) var starredIDs: [Int]
    /// Per-word in-app assessments (wordID → known). Published so the Today
    /// screen can reflect an answer the instant it's recorded — a mark that
    /// doesn't move the band (and so doesn't swap the day's word) still needs
    /// visible acknowledgement.
    @Published private(set) var difficultyMarks: [Int: Bool]
    /// Today's word per enabled language, in the user's language order.
    @Published private(set) var todaysWords: [Word]
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
        #if DEBUG
        if Set(ProcessInfo.processInfo.arguments).contains("-ScreenshotDemo") {
            ScreenshotDemoSeeder.seed(store: store, service: service)
        }
        #endif
        self.theme = store.theme
        let languages = store.enabledLanguages
        self.enabledLanguages = languages
        self.bands = Self.bandsSnapshot(store: store, languages: languages)
        self.onboardingComplete = store.onboardingComplete
        self.starredIDs = store.starredIDs
        self.difficultyMarks = store.difficultyMarks
        self.todaysWords = service.todaysWords(store: store)
        self.widgetPreferences = store.widgetPreferences
        recomputeDue()
        #if DEBUG
        applyLaunchTabSelection()
        #endif
    }

    var corpusIsEmpty: Bool {
        enabledLanguages.allSatisfy { service.library.corpus(for: $0).words.isEmpty }
    }

    func refreshFromStore() {
        theme = store.theme
        onboardingComplete = store.onboardingComplete
        starredIDs = store.starredIDs
        difficultyMarks = store.difficultyMarks
        syncLanguageState()
        widgetPreferences = store.widgetPreferences
        recomputeDue()
    }

    /// Re-snapshot the per-language published state (enabled set, bands, daily
    /// words) from the store — the one incantation every language mutation ends in.
    private func syncLanguageState() {
        enabledLanguages = store.enabledLanguages
        bands = Self.bandsSnapshot(store: store, languages: enabledLanguages)
        todaysWords = service.todaysWords(store: store)
    }

    private static func bandsSnapshot(store: SharedStore, languages: [Language]) -> [Language: Int] {
        Dictionary(uniqueKeysWithValues: languages.map { ($0, store.band(for: $0)) })
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

    // MARK: Languages

    /// Update the set of languages being learned (Settings). The store
    /// normalizes to `Language.allCases` order and guards against an empty set.
    func setLanguages(_ languages: [Language]) {
        store.enabledLanguages = languages
        syncLanguageState()
        WidgetReloader.reload()
    }

    // MARK: Difficulty

    func band(for language: Language) -> Int {
        bands[language] ?? store.band(for: language)
    }

    func setBand(_ value: Int, for language: Language) {
        let clamped = min(max(value, 1), difficulty.maxBand)
        bands[language] = clamped
        store.setBand(clamped, for: language)
        // Only this language's daily word can change — don't re-shuffle the rest.
        if let idx = todaysWords.firstIndex(where: { $0.language == language }),
           let word = service.todaysWord(store: store, language: language) {
            todaysWords[idx] = word
        } else {
            todaysWords = service.todaysWords(store: store)
        }
        WidgetReloader.reload()
    }

    // MARK: Onboarding

    /// The calibrated starting band a set of swipe answers implies — exposed so
    /// onboarding can turn each language's deck into a level as it completes.
    func calibratedBand(from answers: [DifficultyModel.Answer]) -> Int {
        difficulty.calibratedBand(from: answers)
    }

    /// The gentle-middle starting band, for self-assessment defaults and
    /// empty-corpus fallbacks (single source of truth: `DifficultyModel`).
    var defaultBand: Int { difficulty.defaultBand }

    /// Finish onboarding with the chosen languages and each one's starting band
    /// (from the swipe calibration or the self-assessment picker).
    func completeOnboarding(languages: [Language], bands chosen: [Language: Int]) {
        store.enabledLanguages = languages
        for (language, band) in chosen {
            store.setBand(min(max(band, 1), difficulty.maxBand), for: language)
        }
        store.onboardingComplete = true
        onboardingComplete = true
        syncLanguageState()
        WidgetReloader.reload()
    }

    /// The deck of words the swipe step calibrates on for one language.
    func calibrationDeck(for language: Language) -> [Word] {
        service.calibrationSample(language: language, salt: store.installSalt)
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

    /// The base next-review interval (in whole days) each grade would schedule for a
    /// word, from its current saved state — so the study session can show "Good · 3d"
    /// under the buttons before the user commits. Fuzz-free, so it's the stable base
    /// the grade lands on (`grade()` then jitters the final due date a few percent).
    func reviewPreview(_ word: Word, now: Date = Date()) -> [ReviewGrade: Int] {
        engine.preview(store.reviewStates[word.id], now: now)
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
        difficultyMarks = marks
        let language = word.language
        setBand(difficulty.adjusted(band: band(for: language), markedKnown: known, wordBand: word.band),
                for: language)
    }

    /// The in-app assessment recorded for a word: `true` = known, `false` = still
    /// learning, `nil` = not yet marked. Drives the Today screen's answered state
    /// so a tap is acknowledged even when it doesn't move the band (and so the
    /// day's word doesn't visibly change).
    func markState(for id: Int) -> Bool? { difficultyMarks[id] }

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
            store.setBand(2, for: .english)
        }
    }

    private func applyLaunchTabSelection() {
        let args = Set(ProcessInfo.processInfo.arguments)
        if args.contains("-OpenTabSettings") { selectedTab = .settings }
        else if args.contains("-OpenTabPractice") { selectedTab = .practice }
    }
    #endif
}
