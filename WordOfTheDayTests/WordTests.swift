import XCTest
@testable import WordOfTheDay

final class WordTests: XCTestCase {

    func test_partOfSpeechLabels() {
        XCTAssertEqual(Fixtures.word(1, band: 1, pos: "n").partOfSpeechLabel, "noun")
        XCTAssertEqual(Fixtures.word(1, band: 1, pos: "v").partOfSpeechLabel, "verb")
        XCTAssertEqual(Fixtures.word(1, band: 1, pos: "adj").partOfSpeechLabel, "adjective")
        XCTAssertEqual(Fixtures.word(1, band: 1, pos: "adv").partOfSpeechLabel, "adverb")
    }

    func test_unknownPOS_passesThrough() {
        XCTAssertEqual(Fixtures.word(1, band: 1, pos: "interj").partOfSpeechLabel, "interj")
    }

    func test_word_decodesFromJSON() throws {
        let json = """
        {"id": 42, "word": "laconic", "pos": "adj",
         "definition": "using few words", "band": 3}
        """.data(using: .utf8)!
        let word = try JSONDecoder().decode(Word.self, from: json)
        XCTAssertEqual(word.id, 42)
        XCTAssertEqual(word.word, "laconic")
        XCTAssertEqual(word.band, 3)
    }

    func test_word_roundTrips() throws {
        let word = Fixtures.word(7, band: 4, word: "ersatz")
        let decoded = try JSONDecoder().decode(Word.self, from: JSONEncoder().encode(word))
        XCTAssertEqual(word, decoded)
    }
}
