import XCTest
@testable import WordOfTheDay

/// The pure text/voice-selection core of the pronunciation feature. The synthesizer
/// itself (audio session, AVFoundation, delegate callbacks) needs a device and is
/// verified manually; here we pin the device-free decision `SpeechPlan.make` owns.
final class SpeechPlanTests: XCTestCase {

    func testEnglishSpeaksHeadwordWithUSVoice() {
        let plan = SpeechPlan.make(for: Fixtures.word(1, band: 2, word: "ephemeral"))
        XCTAssertEqual(plan, SpeechPlan(text: "ephemeral", voiceLanguage: "en-US"))
    }

    func testJapaneseSpeaksKanaReadingWithJPVoice() {
        let word = Fixtures.word(2, band: 1, word: "お兄さん", reading: "おにいさん", lang: "ja")
        let plan = SpeechPlan.make(for: word)
        XCTAssertEqual(plan, SpeechPlan(text: "おにいさん", voiceLanguage: "ja-JP"))
    }

    func testJapaneseWithoutReadingSpeaksHeadword() {
        let word = Fixtures.word(3, band: 1, word: "ああ", lang: "ja")
        let plan = SpeechPlan.make(for: word)
        XCTAssertEqual(plan, SpeechPlan(text: "ああ", voiceLanguage: "ja-JP"))
    }

    func testJapaneseWithEmptyReadingSpeaksHeadword() {
        let word = Fixtures.word(4, band: 1, word: "山", reading: "", lang: "ja")
        let plan = SpeechPlan.make(for: word)
        XCTAssertEqual(plan, SpeechPlan(text: "山", voiceLanguage: "ja-JP"))
    }

    /// Withholding the reading (e.g. a hidden recognition answer) falls back to the
    /// headword without changing the voice.
    func testJapaneseExcludingReadingSpeaksHeadword() {
        let word = Fixtures.word(5, band: 1, word: "お兄さん", reading: "おにいさん", lang: "ja")
        let plan = SpeechPlan.make(for: word, includeReading: false)
        XCTAssertEqual(plan, SpeechPlan(text: "お兄さん", voiceLanguage: "ja-JP"))
    }
}
