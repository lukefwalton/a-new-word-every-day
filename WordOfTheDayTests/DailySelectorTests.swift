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

    // MARK: Daily advancement + cycles

    /// Words on consecutive days, starting at install. Band 1 over the default
    /// fixtures gives a pool of `perBand` words, so day k is cycle k/perBand.
    private func words(days: Range<Int>, salt: UInt64, band: Int = 1, corpus: [Word]) -> [Word] {
        days.map { offset in
            let date = Fixtures.utc.date(byAdding: .day, value: offset, to: install)!
            return selector.word(on: date, installDate: install, salt: salt, band: band, corpus: corpus)!
        }
    }

    func test_consecutiveDays_giveDifferentWords() {
        let corpus = Fixtures.corpus()
        let d0 = selector.word(on: Fixtures.day(2026, 1, 1), installDate: install, salt: 5, band: 5, corpus: corpus)
        let d1 = selector.word(on: Fixtures.day(2026, 1, 2), installDate: install, salt: 5, band: 5, corpus: corpus)
        XCTAssertNotEqual(d0, d1)
    }

    func test_firstCycle_matchesLegacyShuffleOrder() {
        // Cycle 0 must stay byte-identical to the pre-reshuffle selector, so an
        // app update never changes the word an existing install shows today.
        let corpus = Fixtures.corpus(perBand: 4)
        let pool = corpus.filter { $0.band <= 1 }.sorted { $0.id < $1.id }
        let legacy = pool.seededShuffled(seed: 5)
        XCTAssertEqual(words(days: 0..<4, salt: 5, corpus: corpus), legacy)
    }

    func test_secondCycle_isAPermutationOfThePool() {
        // Every word still appears exactly once per pass through the pool.
        let corpus = Fixtures.corpus(perBand: 4)
        let poolIDs = Set(corpus.filter { $0.band <= 1 }.map(\.id))
        let cycle1IDs = Set(words(days: 4..<8, salt: 5, corpus: corpus).map(\.id))
        XCTAssertEqual(cycle1IDs, poolIDs)
    }

    func test_secondCycle_usesADifferentOrder() {
        // The point of the fix: the second pass is a fresh shuffle, not a replay.
        // (Salt 5 is a pinned value where the two orders are known to differ.)
        let corpus = Fixtures.corpus(perBand: 4)
        XCTAssertNotEqual(words(days: 0..<4, salt: 5, corpus: corpus),
                          words(days: 4..<8, salt: 5, corpus: corpus))
    }

    func test_noAdjacentRepeat_acrossCycleBoundary() {
        // The last word of one cycle never repeats as the first word of the
        // next. With a 4-word pool a naive reshuffle collides for ~1 in 4 salts,
        // so 200 salts exercise the boundary guard many times over.
        let corpus = Fixtures.corpus(perBand: 4)
        for salt in 0..<200 {
            let sequence = words(days: 0..<12, salt: UInt64(salt), corpus: corpus)
            XCTAssertNotEqual(sequence[3], sequence[4], "salt \(salt): repeat across cycle 0→1")
            XCTAssertNotEqual(sequence[7], sequence[8], "salt \(salt): repeat across cycle 1→2")
        }
    }

    func test_threeWordPool_noAdjacentRepeat_acrossCycleBoundary() {
        // Three words is the smallest pool where the boundary guard is active
        // (pool.count > 2) — the sharpest edge of "the swap never disturbs a
        // cycle's last word". Over 300 salts the guard fires for ~a third of
        // them, so this is a real workout, not a happy path.
        let corpus = [Fixtures.word(1, band: 1), Fixtures.word(2, band: 1),
                      Fixtures.word(3, band: 1)]
        for salt in 0..<300 {
            let sequence = words(days: 0..<12, salt: UInt64(salt), corpus: corpus)
            for day in 0..<(sequence.count - 1) {
                XCTAssertNotEqual(sequence[day], sequence[day + 1],
                                  "salt \(salt): adjacent repeat at day \(day)")
            }
            for cycle in 0..<4 {
                XCTAssertEqual(Set(sequence[cycle * 3..<(cycle * 3 + 3)].map(\.id)), [1, 2, 3],
                               "salt \(salt), cycle \(cycle) must be a full permutation")
            }
        }
    }

    func test_singleWordPool_repeatsWithoutCrashing() {
        let corpus = [Fixtures.word(1, band: 1)]
        let sequence = words(days: 0..<3, salt: 5, corpus: corpus)
        XCTAssertEqual(sequence.map(\.id), [1, 1, 1])
    }

    func test_twoWordPool_staysAPermutationEachCycle() {
        // The boundary guard is skipped for pools of 2 (the swap would move the
        // cycle's last word), but each cycle must still cover both words.
        let corpus = [Fixtures.word(1, band: 1), Fixtures.word(2, band: 1)]
        for salt in 0..<20 {
            let sequence = words(days: 0..<10, salt: UInt64(salt), corpus: corpus)
            for cycle in 0..<5 {
                XCTAssertEqual(Set(sequence[cycle * 2..<(cycle * 2 + 2)].map(\.id)), [1, 2],
                               "salt \(salt), cycle \(cycle) must show both words")
            }
        }
    }

    func test_bandChange_pastAFullCycle_isDeterministicPerBand() {
        // §3.3 nuance: the per-cycle seed is salt + (day / pool.count), and
        // pool.count depends on band, so on a day past the lower band's first
        // full pass a band change can move the cycle. That's fine — selection
        // stays a pure function of (date, install, salt, band, corpus): a given
        // band always yields the same word, and the filter is always respected.
        // (A band change already reshuffled the pool in v1; this only pins that
        // the post-exhaustion path is still deterministic and band-scoped.)
        let corpus = Fixtures.corpus(perBand: 4)   // band 1 → 4 words, band 2 → 8
        let day = Fixtures.day(2026, 1, 6)         // day index 5: cycle 1 for band 1
        func word(band: Int) -> Word {
            selector.word(on: day, installDate: install, salt: 9, band: band, corpus: corpus)!
        }
        XCTAssertEqual(word(band: 1), word(band: 1), "band 1 must be deterministic")
        XCTAssertEqual(word(band: 2), word(band: 2), "band 2 must be deterministic")
        XCTAssertLessThanOrEqual(word(band: 1).band, 1)
        XCTAssertLessThanOrEqual(word(band: 2).band, 2)

        // Cycle 0 for *each* band still matches that band's legacy shuffle, so
        // the backward-compat guarantee is per-band, not only for band 1.
        for band in 1...2 {
            let pool = corpus.filter { $0.band <= band }.sorted { $0.id < $1.id }
            let legacy = pool.seededShuffled(seed: 9)
            let firstPass = (0..<pool.count).map { offset -> Word in
                let d = Fixtures.utc.date(byAdding: .day, value: offset, to: install)!
                return selector.word(on: d, installDate: install, salt: 9, band: band, corpus: corpus)!
            }
            XCTAssertEqual(firstPass, legacy, "band \(band) cycle 0 must match its legacy shuffle")
        }
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
