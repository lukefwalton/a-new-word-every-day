import XCTest
@testable import WordOfTheDay

final class DifficultyModelTests: XCTestCase {
    private let model = DifficultyModel()

    private func answers(_ pairs: [(band: Int, known: Bool)]) -> [DifficultyModel.Answer] {
        pairs.map { DifficultyModel.Answer(band: $0.band, known: $0.known) }
    }

    func test_noAnswers_usesDefaultBand() {
        XCTAssertEqual(model.calibratedBand(from: []), 2)
    }

    func test_knowsEverything_landsAtMaxBand() {
        let a = answers((1...5).flatMap { b in [(b, true), (b, true)] })
        XCTAssertEqual(model.calibratedBand(from: a), 5)
    }

    func test_stopsAtFirstBandBelowThreshold() {
        // Knows bands 1–3, fails band 4 → starting band is 3.
        let a = answers([
            (1, true), (1, true),
            (2, true), (2, true),
            (3, true), (3, false),   // 50% but still ≥? no: threshold 0.6 → fails
            (4, false), (4, false),
        ])
        // Band 3 here is 50% known (< 0.6), so it stops at band 2.
        XCTAssertEqual(model.calibratedBand(from: a), 2)
    }

    func test_band3PassesWhenMostlyKnown() {
        let a = answers([
            (1, true), (1, true),
            (2, true), (2, true),
            (3, true), (3, true), (3, false),  // 2/3 ≈ 0.67 ≥ 0.6 → passes
            (4, false), (4, false),
        ])
        XCTAssertEqual(model.calibratedBand(from: a), 3)
    }

    func test_failsEvenBandOne_floorsAtOne() {
        let a = answers([(1, false), (1, false), (1, true)])
        XCTAssertEqual(model.calibratedBand(from: a), 1)
    }

    func test_skippedBandsDoNotBreakTheWalk() {
        // No band-2 answers; band 3 is known. Missing signal shouldn't stop early.
        let a = answers([(1, true), (3, true), (3, true)])
        XCTAssertEqual(model.calibratedBand(from: a), 3)
    }

    // MARK: In-app nudges

    func test_knownAtCeiling_raisesBand() {
        XCTAssertEqual(model.adjusted(band: 3, markedKnown: true, wordBand: 3), 4)
        XCTAssertEqual(model.adjusted(band: 3, markedKnown: true, wordBand: 4), 4)
    }

    func test_knownBelowCeiling_doesNotRaise() {
        XCTAssertEqual(model.adjusted(band: 3, markedKnown: true, wordBand: 2), 3)
    }

    func test_unknownAtOrBelowLevel_lowersBand() {
        XCTAssertEqual(model.adjusted(band: 3, markedKnown: false, wordBand: 3), 2)
        XCTAssertEqual(model.adjusted(band: 3, markedKnown: false, wordBand: 2), 2)
    }

    func test_nudges_clampToRange() {
        XCTAssertEqual(model.adjusted(band: 5, markedKnown: true, wordBand: 5), 5)
        XCTAssertEqual(model.adjusted(band: 1, markedKnown: false, wordBand: 1), 1)
    }
}
