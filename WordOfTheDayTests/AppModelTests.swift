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
            .japanese: WordCorpus(words: Fixtures.corpus(startID: 100, lang: "ja")),
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
                                 bands: [.english: model.calibratedBand(from: answers)])

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

    func test_deepLink_focusesWord() {
        let (model, _) = makeModel()
        model.handle(url: URL(string: "wordoftheday://word/4")!)
        XCTAssertEqual(model.focusedWordID, 4)
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
