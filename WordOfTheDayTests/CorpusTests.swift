import XCTest
@testable import WordOfTheDay

/// Validates the *real* bundled seed corpus (words.json), loaded from the test
/// bundle. Catches a malformed or truncated data file before it ships.
final class CorpusTests: XCTestCase {
    private var corpus: WordCorpus {
        WordCorpus.load(bundles: [Bundle(for: CorpusTests.self)])
    }

    func test_seedCorpus_loads() {
        XCTAssertFalse(corpus.words.isEmpty, "words.json should be bundled with the test target")
    }

    func test_ids_areUniqueAndPositive() {
        let ids = corpus.words.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in words.json")
        XCTAssertTrue(ids.allSatisfy { $0 > 0 })
    }

    func test_lookupByID_works() {
        guard let first = corpus.words.first else { return XCTFail("empty corpus") }
        XCTAssertEqual(corpus.word(id: first.id), first)
        XCTAssertNil(corpus.word(id: -999))
    }

    func test_everyWord_isWellFormed() {
        let validPOS: Set<String> = ["n", "v", "adj", "adv"]
        for word in corpus.words {
            XCTAssertFalse(word.word.trimmingCharacters(in: .whitespaces).isEmpty, "blank headword id=\(word.id)")
            XCTAssertFalse(word.definition.trimmingCharacters(in: .whitespaces).isEmpty, "blank definition id=\(word.id)")
            XCTAssertTrue(validPOS.contains(word.pos), "bad pos '\(word.pos)' id=\(word.id)")
            XCTAssertTrue((1...5).contains(word.band), "band out of range id=\(word.id)")
        }
    }

    func test_allBandsRepresented() {
        let bands = Set(corpus.words.map(\.band))
        XCTAssertEqual(bands, [1, 2, 3, 4, 5], "every difficulty band should have words for calibration to work")
    }

    func test_missingFile_yieldsEmptyCorpusNotCrash() {
        // A bundle with no words.json (the design-system test bundle) → empty, no crash.
        let empty = WordCorpus.load(bundles: [Bundle(for: XCTestCase.self)])
        XCTAssertTrue(empty.words.isEmpty)
    }
}
