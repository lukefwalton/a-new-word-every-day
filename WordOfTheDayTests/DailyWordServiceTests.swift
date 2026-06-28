import XCTest
@testable import WordOfTheDay

final class DailyWordServiceTests: XCTestCase {
    private func service() -> DailyWordService {
        DailyWordService(corpus: WordCorpus(words: Fixtures.corpus()),
                         selector: DailySelector(calendar: Fixtures.utc))
    }

    func test_todaysWord_matchesSelector() {
        let svc = service()
        let store = Fixtures.volatileStore()
        store.band = 5
        let now = Fixtures.day(2026, 5, 1)
        let viaService = svc.todaysWord(store: store, now: now)
        let viaSelector = svc.selector.word(on: now, installDate: store.installDate,
                                            salt: store.installSalt, band: store.band,
                                            corpus: svc.corpus.words)
        XCTAssertEqual(viaService, viaSelector)
    }

    func test_starredWords_reflectStoreOrderAndSkipMissing() {
        let svc = service()
        let store = Fixtures.volatileStore()
        store.toggleStar(3)
        store.toggleStar(7)
        store.toggleStar(9999) // not in corpus → skipped
        let starred = svc.starredWords(store: store).map(\.id)
        XCTAssertEqual(starred, [7, 3], "newest first, missing ids dropped")
    }

    func test_calibrationSample_isDeterministicAndSpansBands() {
        let svc = service()
        let a = svc.calibrationSample(perBand: 3, salt: 555)
        let b = svc.calibrationSample(perBand: 3, salt: 555)
        XCTAssertEqual(a, b, "same salt → same deck")
        XCTAssertEqual(Set(a.map(\.band)), [1, 2, 3, 4, 5], "deck should sample every band")
        XCTAssertEqual(a.count, 15)
    }

    func test_calibrationSample_differsBySalt() {
        let svc = service()
        XCTAssertNotEqual(svc.calibrationSample(perBand: 3, salt: 1),
                          svc.calibrationSample(perBand: 3, salt: 2))
    }
}
