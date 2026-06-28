import XCTest
@testable import WordOfTheDay

final class DailySelectorTests: XCTestCase {
    private let selector = DailySelector(calendar: Fixtures.utc)
    private let install = Fixtures.day(2026, 1, 1)

    // MARK: Determinism (the app/widget contract)

    func test_selection_isIndependentOfCorpusOrder() {
        let corpus = Fixtures.corpus()
        let a = selector.word(on: Fixtures.day(2026, 6, 28), installDate: install, salt: 42, band: 5, corpus: corpus)
        let b = selector.word(on: Fixtures.day(2026, 6, 28), installDate: install, salt: 42, band: 5, corpus: corpus.reversed())
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b, "same inputs must give the same word regardless of load order")
    }

    func test_selection_isStableAcrossCalls() {
        let corpus = Fixtures.corpus()
        let date = Fixtures.day(2026, 3, 15)
        let first = selector.word(on: date, installDate: install, salt: 7, band: 5, corpus: corpus)
        let second = selector.word(on: date, installDate: install, salt: 7, band: 5, corpus: corpus)
        XCTAssertEqual(first, second)
    }

    func test_differentSalts_canGiveDifferentWords() {
        let corpus = Fixtures.corpus()
        let date = Fixtures.day(2026, 3, 15)
        let a = selector.word(on: date, installDate: install, salt: 1, band: 5, corpus: corpus)
        let b = selector.word(on: date, installDate: install, salt: 2, band: 5, corpus: corpus)
        XCTAssertNotEqual(a, b)
    }

    // MARK: Daily advancement + wrap

    func test_consecutiveDays_giveDifferentWords() {
        let corpus = Fixtures.corpus()
        let d0 = selector.word(on: Fixtures.day(2026, 1, 1), installDate: install, salt: 5, band: 5, corpus: corpus)
        let d1 = selector.word(on: Fixtures.day(2026, 1, 2), installDate: install, salt: 5, band: 5, corpus: corpus)
        XCTAssertNotEqual(d0, d1)
    }

    func test_cycleWrapsAfterPoolLength() {
        // Restrict to band 1 → a known pool size of 4, so day 0 and day 4 match.
        let corpus = Fixtures.corpus(perBand: 4)
        let day0 = selector.word(on: Fixtures.day(2026, 1, 1), installDate: install, salt: 5, band: 1, corpus: corpus)
        let day4 = selector.word(on: Fixtures.day(2026, 1, 5), installDate: install, salt: 5, band: 1, corpus: corpus)
        XCTAssertEqual(day0, day4)
    }

    func test_dayIndex_clampsBeforeInstall() {
        // A date before install shouldn't produce a negative index/crash.
        XCTAssertEqual(selector.dayIndex(installDate: install, on: Fixtures.day(2025, 12, 1)), 0)
    }

    // MARK: Band filtering

    func test_band_limitsPool() {
        let corpus = Fixtures.corpus()
        for offset in 0..<30 {
            let date = Fixtures.utc.date(byAdding: .day, value: offset, to: install)!
            let word = selector.word(on: date, installDate: install, salt: 11, band: 2, corpus: corpus)
            XCTAssertNotNil(word)
            XCTAssertLessThanOrEqual(word!.band, 2, "band-2 user should never see a band-3+ word")
        }
    }

    func test_emptyBandFallsBackToWholeCorpus() {
        // Band 0 matches nothing; selector falls back to the full corpus.
        let corpus = Fixtures.corpus()
        let word = selector.word(on: install, installDate: install, salt: 1, band: 0, corpus: corpus)
        XCTAssertNotNil(word)
    }

    func test_emptyCorpus_returnsNil() {
        XCTAssertNil(selector.word(on: install, installDate: install, salt: 1, band: 5, corpus: []))
    }
}
