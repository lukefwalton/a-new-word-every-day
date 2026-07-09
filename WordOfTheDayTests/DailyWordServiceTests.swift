import XCTest
@testable import WordOfTheDay

final class DailyWordServiceTests: XCTestCase {
    private func bilingualService() -> DailyWordService {
        let library = CorpusLibrary(corpora: [
            .english: WordCorpus(words: Fixtures.corpus()),
            .japanese: WordCorpus(words: Fixtures.corpus(startID: 100, lang: "ja")),
        ])
        return DailyWordService(library: library, selector: DailySelector(calendar: Fixtures.utc))
    }

    func test_todaysWord_matchesSelector() {
        let svc = Fixtures.service()
        let store = Fixtures.volatileStore()
        store.setBand(5, for: .english)
        let now = Fixtures.day(2026, 5, 1)
        let viaService = svc.todaysWord(store: store, language: .english, now: now)
        let viaSelector = svc.selector.word(on: now, installDate: store.installDate,
                                            salt: store.installSalt, band: store.band(for: .english),
                                            corpus: svc.library.corpus(for: .english).words)
        XCTAssertEqual(viaService, viaSelector)
    }

    func test_todaysWords_oneWordPerEnabledLanguage_usingEachBand() {
        let svc = bilingualService()
        let store = Fixtures.volatileStore()
        store.enabledLanguages = [.english, .japanese]
        store.setBand(5, for: .english)
        store.setBand(1, for: .japanese)
        let now = Fixtures.day(2026, 5, 1)

        let words = svc.todaysWords(store: store, now: now)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words.map(\.language), [.english, .japanese])
        XCTAssertEqual(words[1].band, 1, "the Japanese word must respect the Japanese band")
    }

    // MARK: Exploration ("keep going") picks

    func test_explorationWord_staysWithinBandAndSkipsSeen() {
        let svc = Fixtures.service()          // 20 words, 4 per band across bands 1…5
        let store = Fixtures.volatileStore()
        store.setBand(2, for: .english)       // eligible pool = bands 1 & 2 (8 words)

        let first = svc.explorationWord(store: store, language: .english, seen: [])
        XCTAssertNotNil(first)
        XCTAssertLessThanOrEqual(first!.band, 2, "exploration respects the band ceiling")

        // Feeding the first pick back as seen yields a different word.
        let second = svc.explorationWord(store: store, language: .english, seen: [first!.id])
        XCTAssertNotNil(second)
        XCTAssertNotEqual(second!.id, first!.id, "a seen word is never served again")
    }

    func test_explorationWord_isDeterministic() {
        let svc = Fixtures.service()
        let store = Fixtures.volatileStore()
        store.setBand(3, for: .english)
        let a = svc.explorationWord(store: store, language: .english, seen: [1, 2])
        let b = svc.explorationWord(store: store, language: .english, seen: [1, 2])
        XCTAssertEqual(a, b, "same install + band + seen ⇒ same next word")
    }

    func test_explorationWord_walksTheWholeBandThenRunsDry() {
        let svc = Fixtures.service()
        let store = Fixtures.volatileStore()
        store.setBand(1, for: .english)       // band 1 only = 4 words (ids 1…4)

        var seen: Set<Int> = []
        var collected: Set<Int> = []
        while let w = svc.explorationWord(store: store, language: .english, seen: seen) {
            collected.insert(w.id)
            seen.insert(w.id)
        }
        XCTAssertEqual(collected, [1, 2, 3, 4], "exploration covers the whole eligible pool")
        XCTAssertNil(svc.explorationWord(store: store, language: .english, seen: seen),
                     "an exhausted pool returns nil")
    }

    func test_wordByID_searchesAllLanguages() {
        let svc = bilingualService()
        XCTAssertEqual(svc.word(id: 3)?.language, .english)
        XCTAssertEqual(svc.word(id: 103)?.language, .japanese)
        XCTAssertNil(svc.word(id: 9999))
    }

    func test_starredWords_reflectStoreOrderAndSkipMissing_acrossLanguages() {
        let svc = bilingualService()
        let store = Fixtures.volatileStore()
        store.toggleStar(3)     // English
        store.toggleStar(107)   // Japanese
        store.toggleStar(9999)  // not in any corpus → skipped
        let starred = svc.starredWords(store: store).map(\.id)
        XCTAssertEqual(starred, [107, 3], "newest first, missing ids dropped")
    }

    func test_calibrationSample_isDeterministicAndSpansBands() {
        let svc = Fixtures.service()
        let a = svc.calibrationSample(language: .english, perBand: 3, salt: 555)
        let b = svc.calibrationSample(language: .english, perBand: 3, salt: 555)
        XCTAssertEqual(a, b, "same salt → same deck")
        XCTAssertEqual(Set(a.map(\.band)), [1, 2, 3, 4, 5], "deck should sample every band")
        XCTAssertEqual(a.count, 15)
    }

    func test_calibrationSample_differsBySalt() {
        let svc = Fixtures.service()
        XCTAssertNotEqual(svc.calibrationSample(language: .english, perBand: 3, salt: 1),
                          svc.calibrationSample(language: .english, perBand: 3, salt: 2))
    }

    func test_calibrationSample_forMissingLanguage_isEmpty() {
        let svc = Fixtures.service()   // English-only library
        XCTAssertTrue(svc.calibrationSample(language: .japanese, salt: 1).isEmpty)
    }
}
