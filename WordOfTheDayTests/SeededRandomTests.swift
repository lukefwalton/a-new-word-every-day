import XCTest
@testable import WordOfTheDay

/// The deterministic RNG underpins daily selection (app and widget must agree),
/// so its stability is load-bearing.
final class SeededRandomTests: XCTestCase {

    func test_sameSeed_producesSameSequence() {
        var a = SeededRandom(seed: 12345)
        var b = SeededRandom(seed: 12345)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func test_differentSeeds_diverge() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        let av = (0..<20).map { _ in a.next() }
        let bv = (0..<20).map { _ in b.next() }
        XCTAssertNotEqual(av, bv)
    }

    func test_seededShuffle_isStableForSeed() {
        let input = Array(1...50)
        XCTAssertEqual(input.seededShuffled(seed: 7), input.seededShuffled(seed: 7))
    }

    func test_seededShuffle_isAPermutation() {
        let input = Array(1...50)
        XCTAssertEqual(input.seededShuffled(seed: 99).sorted(), input)
    }

    func test_seededShuffle_actuallyReorders() {
        let input = Array(1...50)
        // Vanishingly unlikely for a 50-element shuffle to return identity.
        XCTAssertNotEqual(input.seededShuffled(seed: 3), input)
    }

    func test_emptyAndSingle_areSafe() {
        XCTAssertEqual([Int]().seededShuffled(seed: 1), [])
        XCTAssertEqual([42].seededShuffled(seed: 1), [42])
    }
}
