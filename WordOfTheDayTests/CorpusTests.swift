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
            XCTAssertTrue((1...Language.english.maxBand).contains(word.band),
                          "band out of range id=\(word.id)")
        }
    }

    func test_allBandsRepresented() {
        let bands = Set(corpus.words.map(\.band))
        XCTAssertEqual(bands, Set(1...Language.english.maxBand),
                       "every difficulty band should have words for calibration to work")
    }

    /// Selection is exact-band (`DailySelector.eligible`), so a band is a pool a
    /// user lives in for months — a thin one would repeat fast, and an empty one
    /// would trip the whole-corpus fallback. Mirrors `MIN_BAND_SIZE` in
    /// `scripts/build_corpus.py`.
    func test_everyBand_isBigEnoughToStandAlone() {
        let counts = Dictionary(grouping: corpus.words, by: \.band).mapValues(\.count)
        for band in 1...Language.english.maxBand {
            XCTAssertGreaterThanOrEqual(counts[band] ?? 0, 150,
                                        "band \(band) is too thin to be its own daily pool")
        }
    }

    /// Band 6 ("Arcane") exists to hold the words that are genuinely out of
    /// general circulation, so "Rare" no longer has to carry both those and the
    /// merely uncommon.
    func test_arcaneBand_holdsTheHardestWords() {
        let arcane = Set(corpus.words.filter { $0.band == 6 }.map(\.word))
        for word in ["borborygmus", "tergiversate", "floccinaucinihilipilification",
                     "palimpsest", "emolument", "jejune"] {
            XCTAssertTrue(arcane.contains(word), "\(word) belongs in Arcane")
        }
        for word in ["suave", "verdant", "vendetta"] {
            XCTAssertFalse(arcane.contains(word), "\(word) still circulates; it isn't Arcane")
        }
    }

    /// Unassimilated loanwords — the ones that still read as foreign, accents and
    /// all — fail the "guessable from a common English root" test outright, so
    /// they belong in Arcane rather than Rare.
    func test_unassimilatedLoanwords_areArcane() {
        let arcane = Set(corpus.words.filter { $0.band == 6 }.map(\.word))
        for word in ["aperçu", "flâneur", "outré", "recherché", "roué", "soigné",
                     "élan", "sangfroid", "contretemps", "weltschmerz", "saudade"] {
            XCTAssertTrue(arcane.contains(word), "\(word) is still a foreign loan; it belongs in Arcane")
        }
    }

    /// The slaughterhouse register: `abattoir` and the vocabulary of flesh,
    /// blood, and decay around it. Spread across bands on purpose — a word this
    /// grim is no rarer for it, and burying the whole vein in Arcane would keep
    /// it from the readers most likely to want it.
    func test_slaughterRegister_isBandedByRarityNotByMood() {
        let band = Dictionary(corpus.words.map { ($0.word, $0.band) },
                              uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(band["abattoir"], 5, "abattoir is rare and literary, not out of circulation")
        // `?? .max` so a word dropped from the corpus fails here rather than
        // sliding under the bound as a missing zero.
        for word in ["gruesome", "carcass", "gore", "grisly", "carrion", "macabre"] {
            XCTAssertLessThanOrEqual(band[word] ?? .max, 3, "\(word) still circulates; it isn't rare")
        }
        // The middle is the part most liable to drift, since a grim word reads as
        // rarer than it is — so pin it as a range: these stay off both ends,
        // neither demoted to everyday nor swept into Arcane with the deep cuts.
        for word in ["offal", "viscera", "eviscerate", "putrefy", "necropolis",
                     "ossuary", "tallow", "immolate", "effluvium", "gibbet"] {
            XCTAssertTrue((4...5).contains(band[word] ?? 0),
                          "\(word) belongs in the middle of the register, not at either end")
        }
        for word in ["knacker", "fellmonger", "battue", "charnel", "gralloch", "haruspex",
                     "hecatomb", "carnifex", "excarnation", "necrophagous", "ichor"] {
            XCTAssertEqual(band[word], 6, "\(word) is genuinely out of general circulation")
        }
    }

    /// The reported bug in corpus terms: `lax` is a band-2 word and must stay
    /// one, so no level above Easy can ever serve it.
    func test_laxStaysAnEasyWord() {
        XCTAssertEqual(corpus.words.first { $0.word == "lax" }?.band, 2)
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
            XCTAssertTrue((1...Language.japanese.maxBand).contains(word.band),
                          "band out of range id=\(word.id)")
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

    /// English gained a 6th band; Japanese must not, because its bands *are*
    /// JLPT N5…N1 and there is no sixth level to name.
    func test_japanese_hasNoSixthBand() {
        XCTAssertEqual(Language.japanese.maxBand, 5)
        XCTAssertFalse(japanese.words.contains { $0.band > 5 })
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
