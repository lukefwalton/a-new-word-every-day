import XCTest
@testable import WordOfTheDay

/// Validates the *real* bundled seed corpora (words.json, words_ja.json), loaded
/// from the test bundle. Catches a malformed or truncated data file before it
/// ships.
final class CorpusTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: CorpusTests.self) }
    private var corpus: WordCorpus {
        WordCorpus.load(bundles: [bundle])
    }
    private var japanese: WordCorpus {
        WordCorpus.load(language: .japanese, bundles: [bundle])
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
            XCTAssertTrue(validPOS.contains(word.pos), "bad pos '\(word.pos)' id=\(word.id)")  // n|v|adj|adv
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

    // MARK: Japanese corpus

    func test_japaneseCorpus_loads() {
        XCTAssertFalse(japanese.words.isEmpty, "words_ja.json should be bundled with the test target")
    }

    func test_japaneseWords_areWellFormed() {
        let validPOS: Set<String> = ["n", "v", "adj", "adv", "expr"]
        for word in japanese.words {
            XCTAssertFalse(word.word.trimmingCharacters(in: .whitespaces).isEmpty, "blank headword id=\(word.id)")
            XCTAssertFalse(word.definition.trimmingCharacters(in: .whitespaces).isEmpty, "blank definition id=\(word.id)")
            XCTAssertTrue(validPOS.contains(word.pos), "bad pos '\(word.pos)' id=\(word.id)")
            XCTAssertTrue((1...5).contains(word.band), "band out of range id=\(word.id)")
            XCTAssertEqual(word.language, .japanese, "lang tag missing id=\(word.id)")
            if let reading = word.reading {
                XCTAssertFalse(reading.isEmpty, "empty reading id=\(word.id)")
                XCTAssertNotEqual(reading, word.word, "redundant reading should be omitted id=\(word.id)")
            }
        }
    }

    func test_japaneseBandsAllRepresented() {
        XCTAssertEqual(Set(japanese.words.map(\.band)), [1, 2, 3, 4, 5],
                       "bands 1…5 are JLPT N5…N1; every level should have words")
    }

    // MARK: Library

    func test_library_loadsEveryLanguage_withGloballyUniqueIDs() {
        let library = CorpusLibrary.load(bundles: [bundle])
        var allIDs: [Int] = []
        for language in Language.allCases {
            let words = library.corpus(for: language).words
            XCTAssertFalse(words.isEmpty, "\(language.displayName) corpus missing")
            allIDs.append(contentsOf: words.map(\.id))
        }
        XCTAssertEqual(Set(allIDs).count, allIDs.count,
                       "ids must be unique across languages — starred/review state is one global map")
    }

    func test_library_wordByID_findsBothLanguages() {
        let library = CorpusLibrary.load(bundles: [bundle])
        guard let en = library.corpus(for: .english).words.first,
              let ja = library.corpus(for: .japanese).words.first else {
            return XCTFail("both corpora should be bundled")
        }
        XCTAssertEqual(library.word(id: en.id), en)
        XCTAssertEqual(library.word(id: ja.id), ja)
    }
}
