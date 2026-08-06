import XCTest
@testable import WordOfTheDay

/// Difficulty ceilings are per-language and derived from `levelNames`, so the
/// level picker, the settings stepper, and `DifficultyModel` all read the same
/// number. These pin that derivation and the two languages' actual ceilings.
final class LanguageTests: XCTestCase {

    func test_everyLanguage_hasADescriptionForEveryLevel() {
        for language in Language.allCases {
            XCTAssertEqual(language.levelNames.count, language.maxBand,
                           "\(language.displayName): maxBand must match levelNames")
            XCTAssertEqual(language.levelDescriptions.count, language.maxBand,
                           "\(language.displayName): every level needs a picker description")
            XCTAssertFalse(language.levelNames.contains { $0.isEmpty })
            XCTAssertFalse(language.levelDescriptions.contains { $0.isEmpty })
        }
    }

    func test_english_topsOutAtArcane() {
        XCTAssertEqual(Language.english.maxBand, 6)
        XCTAssertEqual(Language.english.levelName(forBand: 6), "Arcane")
    }

    /// Japanese bands *are* JLPT N5…N1 — there is no sixth level to name, so it
    /// must not inherit English's Arcane tier.
    func test_japanese_staysOnTheJLPTScale() {
        XCTAssertEqual(Language.japanese.maxBand, 5)
        XCTAssertEqual(Language.japanese.levelNames, ["N5", "N4", "N3", "N2", "N1"])
    }

    func test_levelName_clampsOutOfRangeBands() {
        XCTAssertEqual(Language.english.levelName(forBand: 0), "Gentle")
        XCTAssertEqual(Language.english.levelName(forBand: 99), "Arcane")
        XCTAssertEqual(Language.japanese.levelName(forBand: 99), "N1")
    }
}
