import XCTest
@testable import WordOfTheDay

final class KanaRomajiTests: XCTestCase {
    private func romaji(_ kana: String) -> String? { KanaRomaji.romaji(from: kana) }

    func test_basicHiragana() {
        XCTAssertEqual(romaji("ねこ"), "neko")
        XCTAssertEqual(romaji("さくら"), "sakura")
        XCTAssertEqual(romaji("ありがとう"), "arigatou")
    }

    func test_katakanaFoldsToSameRomaji() {
        XCTAssertEqual(romaji("ネコ"), "neko")
        // Katakana and hiragana of the same reading agree.
        XCTAssertEqual(romaji("カ"), romaji("か"))
    }

    func test_dakutenAndHandakuten() {
        XCTAssertEqual(romaji("がっこう"), "gakkou")
        XCTAssertEqual(romaji("ぱん"), "pan")
        XCTAssertEqual(romaji("べんきょう"), "benkyou")
    }

    func test_youon() {
        XCTAssertEqual(romaji("きょう"), "kyou")
        XCTAssertEqual(romaji("しゃしん"), "shashin")
        XCTAssertEqual(romaji("じゃ"), "ja")
        XCTAssertEqual(romaji("りょこう"), "ryokou")
    }

    func test_sokuonDoublesConsonant() {
        XCTAssertEqual(romaji("きっぷ"), "kippu")
        XCTAssertEqual(romaji("ざっし"), "zasshi")
        // ち-row geminates as "tch" in Hepburn.
        XCTAssertEqual(romaji("まっちゃ"), "matcha")
    }

    func test_katakanaLongVowelMark() {
        XCTAssertEqual(romaji("コーヒー"), "koohii")
        XCTAssertEqual(romaji("ペット"), "petto")
        XCTAssertEqual(romaji("スーパー"), "suupaa")
    }

    func test_syllabicN() {
        XCTAssertEqual(romaji("にほん"), "nihon")
        XCTAssertEqual(romaji("こんにちは"), "konnichiha")
        // n' before a vowel or y keeps the syllable boundary readable.
        XCTAssertEqual(romaji("しんゆう"), "shin'yuu")
    }

    func test_loanwordCombos() {
        XCTAssertEqual(romaji("パーティー"), "paatii")
        XCTAssertEqual(romaji("フォーク"), "fooku")
    }

    func test_nonKanaReturnsNil() {
        XCTAssertNil(romaji(""))
        XCTAssertNil(romaji("会社"), "kanji has no reliable romaji here")
        XCTAssertNil(romaji("hello"))
    }

    func test_wordRomaji_onlyForJapanese() {
        let english = Word(id: 1, word: "laconic", pos: "adj", definition: "brief", band: 4)
        XCTAssertNil(english.romaji)

        // Kana-only headword (no separate reading) romanizes from the word itself.
        let loan = Word(id: 2, word: "ペット", pos: "n", definition: "pet", band: 1, lang: "ja")
        XCTAssertEqual(loan.romaji, "petto")

        // Kanji headword romanizes from its kana reading.
        let kanji = Word(id: 3, word: "会社", pos: "n", definition: "company", band: 2,
                         reading: "かいしゃ", lang: "ja")
        XCTAssertEqual(kanji.romaji, "kaisha")
    }
}
