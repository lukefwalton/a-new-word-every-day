import AVFoundation

/// Device-free description of what to speak for a word: the string and the BCP-47
/// voice language. Split from the synthesizer so the "what to say / which voice"
/// choice is a pure value decision the tests can pin down without AVFoundation or a
/// device. Mirrors `IntervalLabel`'s file-scope-but-internal shape so
/// `@testable import WordOfTheDay` reaches it.
struct SpeechPlan: Equatable {
    /// The text handed to the synthesizer.
    let text: String
    /// BCP-47 voice language, e.g. "en-US", "ja-JP".
    let voiceLanguage: String

    /// Choose the utterance for a word.
    ///
    /// - Parameter includeReading: when false, the Japanese kana `reading` is
    ///   suppressed and the headword is spoken instead — defense-in-depth so a
    ///   caller can never leak a hidden answer through pronunciation (the Review
    ///   session only shows the speak button after reveal, but this keeps the plan
    ///   honest on its own).
    static func make(for word: Word, includeReading: Bool = true) -> SpeechPlan {
        switch word.language {
        case .english:
            return SpeechPlan(text: word.word, voiceLanguage: "en-US")
        case .japanese:
            // Kana is the cleanest input for a kanji headword — `reading` is already
            // kana. Fall back to the headword when it's absent (kana-only words) or
            // when the caller asks to withhold it.
            let reading = (word.reading?.isEmpty == false) ? word.reading : nil
            let text = (includeReading ? reading : nil) ?? word.word
            return SpeechPlan(text: text, voiceLanguage: "ja-JP")
        }
    }
}

/// A thin wrapper over `AVSpeechSynthesizer` for on-device pronunciation. Fully
/// offline — no network, no permissions, no privacy manifest entry. Owned strongly
/// by `AppModel` (a synthesizer must outlive its utterance or speech cuts off), and
/// kept a plain class (not `ObservableObject`) so `AppModel` mirrors its state into
/// a real `@Published` that views can observe.
@MainActor
final class SpeechService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    /// Fired on the main actor when the *current* utterance ends. Cleared once it
    /// runs so a superseded utterance's late cancel can't fire it twice.
    private var onFinish: (() -> Void)?
    /// Identity of the utterance whose completion is `onFinish`. When a new speak
    /// interrupts an old one, the old utterance's `didCancel` carries the old id and
    /// is ignored — only the live utterance's end fires the completion.
    private var currentUtteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak a plan, interrupting anything already in flight. `completion` runs when
    /// this utterance actually stops (finished or cancelled by a later `stop`),
    /// never when a *previous* utterance it replaced is cancelled.
    func speak(_ plan: SpeechPlan, completion: @escaping () -> Void) {
        onFinish = completion

        // User-initiated content they explicitly asked to hear, so it should play
        // even with the ring/silent switch on (`.playback`). `.duckOthers` dips
        // background audio for the utterance instead of stopping it. A session
        // hiccup must never crash a privacy-first vocab app — hence `try?`.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: plan.text)
        utterance.voice = Self.voice(for: plan.voiceLanguage)
        currentUtteranceID = ObjectIdentifier(utterance)

        synthesizer.stopSpeaking(at: .immediate)   // cancel any prior utterance first
        synthesizer.speak(utterance)
    }

    /// Stop any current pronunciation immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Resolve a voice, degrading gracefully: exact BCP-47 code → bare language
    /// ("ja-JP" → "ja") → `nil` (the synthesizer then uses the system default). The
    /// en/ja voices ship on effectively every iOS 17 device, so this almost never
    /// falls through.
    private static func voice(for language: String) -> AVSpeechSynthesisVoice? {
        if let exact = AVSpeechSynthesisVoice(language: language) { return exact }
        let bare = String(language.prefix(while: { $0 != "-" }))
        return AVSpeechSynthesisVoice(language: bare)
    }

    /// Release the audio session, notifying other apps so their audio returns to
    /// full volume after ducking.
    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// End of a specific utterance. Ignored unless it's the live one — a stale
    /// cancel from a replaced utterance must not clear the new word's state.
    private func finish(_ utteranceID: ObjectIdentifier) {
        guard utteranceID == currentUtteranceID else { return }
        currentUtteranceID = nil
        deactivateSession()
        let callback = onFinish
        onFinish = nil
        callback?()
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in finish(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in finish(id) }
    }
}
