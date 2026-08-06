import XCTest
import LFWDesignSystem
@testable import WordOfTheDay

@MainActor
final class AppModelTests: XCTestCase {

    private func makeModel() -> (AppModel, SharedStore) {
        let store = Fixtures.volatileStore()
        return (AppModel(service: Fixtures.service(), store: store), store)
    }

    /// A model over an English + Japanese library, for multilanguage tests.
    private func makeBilingualModel() -> (AppModel, SharedStore) {
        let store = Fixtures.volatileStore()
        let library = CorpusLibrary(corpora: [
            .english: WordCorpus(words: Fixtures.corpus()),
            .japanese: WordCorpus(words: Fixtures.corpus(bands: Language.japanese.maxBand, startID: 100, lang: "ja")),
        ])
        let service = DailyWordService(library: library,
                                       selector: DailySelector(calendar: Fixtures.utc))
        return (AppModel(service: service, store: store), store)
    }

    func test_completeOnboarding_setsBandAndFlag_andWritesThrough() {
        let (model, store) = makeModel()
        XCTAssertFalse(model.onboardingComplete)

        let answers = (1...5).flatMap { b in
            [DifficultyModel.Answer(band: b, known: b <= 3)] // knows up to band 3
        }
        model.completeOnboarding(languages: [.english],
                                 bands: [.english: model.calibratedBand(from: answers, for: .english)])

        XCTAssertTrue(model.onboardingComplete)
        XCTAssertTrue(store.onboardingComplete)
        XCTAssertEqual(model.band(for: .english), 3)
        XCTAssertEqual(store.band(for: .english), 3)
        XCTAssertNotNil(model.todaysWords.first)
    }

    func test_skipOnboarding_usesDefaultBand() {
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [:])
        XCTAssertTrue(model.onboardingComplete)
        XCTAssertEqual(model.band(for: .english), 2)
    }

    func test_completeOnboarding_bilingual_setsIndependentBands() {
        let (model, store) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 4, .japanese: 1])
        XCTAssertEqual(store.enabledLanguages, [.english, .japanese])
        XCTAssertEqual(model.band(for: .english), 4)
        XCTAssertEqual(model.band(for: .japanese), 1)
        XCTAssertEqual(model.todaysWords.count, 2, "one daily word per enabled language")
        XCTAssertEqual(model.todaysWords.map(\.language), [.english, .japanese])
    }

    func test_toggleStar_updatesPublishedAndStore() {
        let (model, store) = makeModel()
        model.toggleStar(5)
        XCTAssertTrue(model.isStarred(5))
        XCTAssertEqual(store.starredIDs, [5])
        model.toggleStar(5)
        XCTAssertFalse(model.isStarred(5))
        XCTAssertEqual(store.starredIDs, [])
    }

    func test_setTheme_writesThrough() {
        let (model, store) = makeModel()
        let theme = LFWThemeConfig(typeface: .recursive, palette: .paper, accentHueShift: 10)
        model.setTheme(theme)
        XCTAssertEqual(model.theme, theme)
        XCTAssertEqual(store.theme, theme)
    }

    func test_setBand_refreshesTodaysWord() {
        let (model, _) = makeModel()
        model.setBand(5, for: .english)
        XCTAssertEqual(model.band(for: .english), 5)
        XCTAssertNotNil(model.todaysWords.first)
    }

    func test_markKnownAtCeiling_raisesBand() {
        let (model, store) = makeModel()
        model.setBand(2, for: .english)
        let bandTwoWord = Fixtures.word(99, band: 2)
        model.mark(bandTwoWord, known: true)
        XCTAssertEqual(model.band(for: .english), 3)
        XCTAssertEqual(store.difficultyMarks[99], true)
    }

    /// The ceiling is per-language: English can be nudged into band 6 ("Arcane"),
    /// Japanese stops at 5 because its bands are JLPT N5…N1.
    func test_markKnown_respectsEachLanguagesCeiling() {
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 5, .japanese: 5])

        model.mark(Fixtures.word(98, band: 5), known: true)
        XCTAssertEqual(model.band(for: .english), 6, "English should reach Arcane")
        model.mark(Fixtures.word(97, band: 6), known: true)
        XCTAssertEqual(model.band(for: .english), 6, "band 6 is English's ceiling")

        model.mark(Fixtures.word(151, band: 5, lang: "ja"), known: true)
        XCTAssertEqual(model.band(for: .japanese), 5, "Japanese must not go past N1")
    }

    func test_setBand_clampsToTheLanguagesCeiling() {
        let (model, _) = makeBilingualModel()
        model.setBand(9, for: .english)
        XCTAssertEqual(model.band(for: .english), 6)
        model.setBand(9, for: .japanese)
        XCTAssertEqual(model.band(for: .japanese), 5)
    }

    func test_mark_japaneseWord_nudgesOnlyJapaneseBand() {
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 3, .japanese: 2])
        let jaWord = Fixtures.word(150, band: 2, lang: "ja")
        model.mark(jaWord, known: true)
        XCTAssertEqual(model.band(for: .japanese), 3, "knowing a ceiling word raises the ja band")
        XCTAssertEqual(model.band(for: .english), 3, "the English band must not move")
    }

    func test_mark_isIdempotent_repeatedSameTapDoesNotRatchetBand() {
        let (model, _) = makeModel()
        model.setBand(2, for: .english)
        let word = Fixtures.word(99, band: 2)
        model.mark(word, known: true)   // 2 → 3
        model.mark(word, known: true)   // no-op (same mark)
        model.mark(word, known: true)   // no-op
        XCTAssertEqual(model.band(for: .english), 3, "repeated identical marks must not keep moving the band")
    }

    func test_markState_reflectsRecordedMark() {
        let (model, _) = makeModel()
        model.setBand(2, for: .english)
        let word = Fixtures.word(99, band: 2)
        XCTAssertNil(model.markState(for: 99), "an unmarked word reports no answer")
        model.mark(word, known: true)
        XCTAssertEqual(model.markState(for: 99), true, "a known mark is reflected immediately")
        model.mark(word, known: false)  // a changed answer
        XCTAssertEqual(model.markState(for: 99), false, "a changed answer updates the reported mark")
    }

    func test_markState_survivesBandUnchangedMark() {
        // A word below the current band leaves the band (and today's word) put;
        // the mark must still be recorded so the UI can acknowledge the tap.
        let (model, _) = makeModel()
        model.setBand(4, for: .english)
        let easyWord = Fixtures.word(99, band: 1)
        model.mark(easyWord, known: true)
        XCTAssertEqual(model.band(for: .english), 4, "a below-band word doesn't move the band")
        XCTAssertEqual(model.markState(for: 99), true, "but the mark is still recorded")
    }

    func test_refreshFromStore_republishesMarkState() {
        let (model, store) = makeModel()
        var marks = store.difficultyMarks
        marks[42] = true
        store.difficultyMarks = marks
        model.refreshFromStore()
        XCTAssertEqual(model.markState(for: 42), true)
    }

    // MARK: Today's "keep going" flow

    func test_assess_advancesToAFreshWord() {
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 3])
        let daily = model.displayWord(for: .english)!
        XCTAssertFalse(model.isExploring(.english), "starts on the canonical daily word")

        model.assess(daily, known: true)

        XCTAssertTrue(model.isExploring(.english), "assessing advances into the keep-going flow")
        let next = model.displayWord(for: .english)!
        XCTAssertNotEqual(next.id, daily.id, "a fresh word replaces the one just assessed")
    }

    func test_assess_neverServesAWordMarkedKnown() {
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 5])
        var shown = Set<Int>()
        var current = model.displayWord(for: .english)!
        // Sweep several words; each shown word gets marked known as we pass it.
        for _ in 0..<6 {
            shown.insert(current.id)
            model.assess(current, known: true)
            guard !model.isCaughtUp(.english) else { break }
            current = model.displayWord(for: .english)!
            XCTAssertFalse(shown.contains(current.id), "a known word is never served again")
        }
    }

    func test_backToToday_restoresCanonicalWord() {
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 3])
        let daily = model.displayWord(for: .english)!
        model.assess(daily, known: true)
        XCTAssertTrue(model.isExploring(.english))

        model.backToToday(.english)

        XCTAssertFalse(model.isExploring(.english))
        XCTAssertEqual(model.displayWord(for: .english)?.id, model.todaysWords.first?.id,
                       "back-to-today shows the canonical word of the day again")
    }

    func test_assess_reportsCaughtUp_whenBandExhausted() {
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 1]) // band 1 = 4 words
        var current = model.displayWord(for: .english)!
        // "Still learning" holds the band at 1 (marking known would raise it and
        // grow the pool), so this small band actually runs dry.
        for _ in 0..<10 {
            model.assess(current, known: false)
            if model.isCaughtUp(.english) { break }
            current = model.displayWord(for: .english)!
        }
        XCTAssertTrue(model.isCaughtUp(.english), "sweeping a tiny band dry reports caught-up")
    }

    func test_assess_onlyAdvancesTheAssessedLanguage() {
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 3, .japanese: 3])
        let english = model.displayWord(for: .english)!
        model.assess(english, known: true)
        XCTAssertTrue(model.isExploring(.english))
        XCTAssertFalse(model.isExploring(.japanese), "the other language stays on its daily word")
    }

    func test_mark_changedAnswer_stillNudges() {
        let (model, _) = makeModel()
        model.setBand(3, for: .english)
        let word = Fixtures.word(99, band: 3)
        model.mark(word, known: true)    // first mark: 3 → 4
        model.mark(word, known: false)   // a *changed* answer still takes effect
        // The changed mark is persisted (not dropped by the idempotence guard).
        XCTAssertEqual(model.store.difficultyMarks[99], false)
    }

    func test_setLanguages_addsDailyWord_andSurvivesEmptyGuard() {
        let (model, store) = makeBilingualModel()
        model.setLanguages([.english, .japanese])
        XCTAssertEqual(model.todaysWords.count, 2)
        model.setLanguages([])
        XCTAssertEqual(store.enabledLanguages, [.english], "the store must never go languageless")
        XCTAssertEqual(model.todaysWords.count, 1)
    }

    func test_japaneseOnlyOnboarding_makesJapanesePrimary() {
        // Deselecting English entirely is valid — Japanese becomes the only
        // (and therefore primary) language for Today, widgets, and Settings.
        let (model, store) = makeBilingualModel()
        model.completeOnboarding(languages: [.japanese], bands: [.japanese: 3])
        XCTAssertEqual(store.enabledLanguages, [.japanese])
        XCTAssertEqual(store.primaryLanguage, .japanese)
        XCTAssertEqual(model.todaysWords.map(\.language), [.japanese])
        XCTAssertEqual(model.band(for: .japanese), 3)
    }

    func test_disablingLanguage_keepsItsStarredAndDueWords() {
        // Product rule: disabling a language stops its daily word, not the
        // user's saved study progress — stars and due counts stay intact.
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 2, .japanese: 2])
        model.toggleStar(103)   // a Japanese word (fixture ids 100+)
        XCTAssertEqual(model.dueCount, 1)

        model.setLanguages([.english])
        XCTAssertEqual(model.todaysWords.map(\.language), [.english], "no Japanese daily word")
        XCTAssertEqual(model.starredWords.map(\.id), [103], "saved words survive disabling")
        XCTAssertEqual(model.dueCount, 1, "review queue keeps disabled-language cards")
    }

    func test_refreshFromStore_picksUpExternalStarChange() {
        let (model, store) = makeModel()
        store.toggleStar(8)   // simulate a widget-side star while the app is warm
        XCTAssertFalse(model.isStarred(8), "cache is stale until refresh")
        model.refreshFromStore()
        XCTAssertTrue(model.isStarred(8), "foreground refresh should surface widget changes")
    }

    func test_refreshFromStore_picksUpThemeAndOnboardingChanges() {
        let (model, store) = makeModel()
        store.theme = LFWThemeConfig(typeface: .literata, palette: .sepia)
        store.onboardingComplete = true
        model.refreshFromStore()
        XCTAssertEqual(model.theme.typeface, .literata)
        XCTAssertEqual(model.theme.palette, .sepia)
        XCTAssertTrue(model.onboardingComplete)
    }

    func test_openWord_focusesAndSwitchesToTodayTab() {
        let (model, _) = makeModel()
        model.selectedTab = .practice
        model.openWord(4)
        XCTAssertEqual(model.focusedWordID, 4)
        XCTAssertEqual(model.selectedTab, .today)
    }

    func test_reselectingSameWord_stillNavigatesToToday() {
        let (model, _) = makeModel()
        model.openWord(4)
        model.selectedTab = .practice      // user goes back to Practice
        model.openWord(4)                  // taps the *same* saved word again
        XCTAssertEqual(model.selectedTab, .today, "same id must still route to Today")
    }

    func test_deepLink_opensTodayOnPager_notFocused() {
        // A widget tap should land on the normal Today pager (not the forked
        // single-word takeover), fronting the tapped word's language.
        let (model, _) = makeModel()
        model.selectedTab = .practice
        model.handle(url: URL(string: "wordoftheday://word/4")!)
        XCTAssertEqual(model.selectedTab, .today)
        XCTAssertNil(model.focusedWordID, "widget taps must not fork into a focused view")
        XCTAssertEqual(model.todayLanguage, .english)
    }

    func test_deepLink_frontsTappedLanguage() {
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english, .japanese],
                                 bands: [.english: 3, .japanese: 3])
        model.todayLanguage = .english
        // id 100+ are the Japanese fixture corpus.
        model.handle(url: URL(string: "wordoftheday://word/104")!)
        XCTAssertEqual(model.todayLanguage, .japanese, "tapping the JA widget fronts Japanese")
        XCTAssertNil(model.focusedWordID)
    }

    func test_deepLink_clearsExplorationForTappedLanguage() {
        // Tapping the widget shows that language's canonical daily word, not an
        // in-app "keep going" word the user had advanced to.
        let (model, _) = makeModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 3])
        model.assess(model.displayWord(for: .english)!, known: true)
        XCTAssertTrue(model.isExploring(.english))
        model.handle(url: URL(string: "wordoftheday://word/4")!)
        XCTAssertFalse(model.isExploring(.english), "widget tap returns to today's word")
    }

    func test_deepLink_disabledLanguage_fallsBackToFocused() {
        // The word exists but its language isn't enabled — still show it (focused)
        // rather than dropping the tap.
        let (model, _) = makeBilingualModel()
        model.completeOnboarding(languages: [.english], bands: [.english: 3])
        model.handle(url: URL(string: "wordoftheday://word/104")!)  // a Japanese word
        XCTAssertEqual(model.focusedWordID, 104)
        XCTAssertEqual(model.selectedTab, .today)
    }

    func test_deepLink_ignoresForeignScheme() {
        let (model, _) = makeModel()
        model.handle(url: URL(string: "https://example.com/word/4")!)
        XCTAssertNil(model.focusedWordID)
    }

    // MARK: Review (in-app study)

    func test_starredWord_isDueForReview() {
        let (model, _) = makeModel()
        let word = Fixtures.word(7, band: 2)
        model.toggleStar(word.id)
        XCTAssertTrue(model.dueWords().contains(word), "a freshly starred word is due immediately")
        XCTAssertEqual(model.dueCount, 1)
    }

    func test_gradeGood_schedulesOutAndClearsDue() {
        let (model, _) = makeModel()
        let word = Fixtures.word(7, band: 2)
        model.toggleStar(word.id)
        model.grade(word, .good)
        XCTAssertFalse(model.dueWords().contains(word), "Good schedules the word into the future")
        XCTAssertEqual(model.dueCount, 0)
    }

    func test_unstar_dropsReviewSchedule() {
        let (model, store) = makeModel()
        let word = Fixtures.word(7, band: 2)
        model.toggleStar(word.id)
        model.grade(word, .good)
        XCTAssertNotNil(store.reviewStates[word.id], "grading persists a schedule")
        model.toggleStar(word.id)   // unstar
        XCTAssertNil(store.reviewStates[word.id], "leaving the deck drops the schedule")
    }
}
