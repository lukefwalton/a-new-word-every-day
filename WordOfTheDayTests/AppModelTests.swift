import XCTest
import LFWDesignSystem
@testable import WordOfTheDay

@MainActor
final class AppModelTests: XCTestCase {

    private func makeModel() -> (AppModel, SharedStore) {
        let store = Fixtures.volatileStore()
        let service = DailyWordService(corpus: WordCorpus(words: Fixtures.corpus()),
                                       selector: DailySelector(calendar: Fixtures.utc))
        return (AppModel(service: service, store: store), store)
    }

    func test_completeOnboarding_setsBandAndFlag_andWritesThrough() {
        let (model, store) = makeModel()
        XCTAssertFalse(model.onboardingComplete)

        let answers = (1...5).flatMap { b in
            [DifficultyModel.Answer(band: b, known: b <= 3)] // knows up to band 3
        }
        model.completeOnboarding(answers: answers)

        XCTAssertTrue(model.onboardingComplete)
        XCTAssertTrue(store.onboardingComplete)
        XCTAssertEqual(model.band, 3)
        XCTAssertEqual(store.band, 3)
        XCTAssertNotNil(model.today)
    }

    func test_skipOnboarding_usesDefaultBand() {
        let (model, _) = makeModel()
        model.completeOnboarding(answers: [])
        XCTAssertTrue(model.onboardingComplete)
        XCTAssertEqual(model.band, 2)
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
        model.setBand(5)
        XCTAssertEqual(model.band, 5)
        XCTAssertNotNil(model.today)
    }

    func test_markKnownAtCeiling_raisesBand() {
        let (model, store) = makeModel()
        model.setBand(2)
        let bandTwoWord = Fixtures.word(99, band: 2)
        model.mark(bandTwoWord, known: true)
        XCTAssertEqual(model.band, 3)
        XCTAssertEqual(store.difficultyMarks[99], true)
    }

    func test_mark_isIdempotent_repeatedSameTapDoesNotRatchetBand() {
        let (model, _) = makeModel()
        model.setBand(2)
        let word = Fixtures.word(99, band: 2)
        model.mark(word, known: true)   // 2 → 3
        model.mark(word, known: true)   // no-op (same mark)
        model.mark(word, known: true)   // no-op
        XCTAssertEqual(model.band, 3, "repeated identical marks must not keep moving the band")
    }

    func test_mark_changedAnswer_stillNudges() {
        let (model, _) = makeModel()
        model.setBand(3)
        let word = Fixtures.word(99, band: 3)
        model.mark(word, known: true)    // first mark: 3 → 4
        model.mark(word, known: false)   // a *changed* answer still takes effect
        // The changed mark is persisted (not dropped by the idempotence guard).
        XCTAssertEqual(model.store.difficultyMarks[99], false)
    }

    func test_refreshFromStore_picksUpExternalStarChange() {
        let (model, store) = makeModel()
        store.toggleStar(8)   // simulate a widget-side star while the app is warm
        XCTAssertFalse(model.isStarred(8), "cache is stale until refresh")
        model.refreshFromStore()
        XCTAssertTrue(model.isStarred(8), "foreground refresh should surface widget changes")
    }

    func test_deepLink_focusesWord() {
        let (model, _) = makeModel()
        model.handle(url: URL(string: "wordoftheday://word/4")!)
        XCTAssertEqual(model.focusedWordID, 4)
    }

    func test_deepLink_ignoresForeignScheme() {
        let (model, _) = makeModel()
        model.handle(url: URL(string: "https://example.com/word/4")!)
        XCTAssertNil(model.focusedWordID)
    }
}
