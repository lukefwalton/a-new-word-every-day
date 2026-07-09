import Foundation

/// One vocabulary entry. Matches the JSON produced by scripts/build_corpus.py.
/// Value type, Codable, deterministic — the whole app
/// and widget reason over arrays of these.
struct Word: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let word: String
    /// "n" | "v" | "adj" | "adv" | "expr".
    let pos: String
    let definition: String
    /// Difficulty band, 1 (most accessible) … 5 (rarest/hardest).
    /// For Japanese, bands 1…5 are JLPT N5…N1.
    let band: Int
    /// Phonetic reading (kana for Japanese). Absent for Latin-script corpora,
    /// and omitted when it would just repeat the headword (kana-only words).
    let reading: String?
    /// Language code ("en", "ja"). Absent in the original English corpus, so
    /// `language` treats nil as English.
    let lang: String?

    init(id: Int, word: String, pos: String, definition: String, band: Int,
         reading: String? = nil, lang: String? = nil) {
        self.id = id
        self.word = word
        self.pos = pos
        self.definition = definition
        self.band = band
        self.reading = reading
        self.lang = lang
    }

    var language: Language {
        lang.flatMap(Language.init(rawValue:)) ?? .english
    }

    /// The reading to display under the headword, if it adds information.
    var displayReading: String? {
        guard let reading, !reading.isEmpty, reading != word else { return nil }
        return reading
    }

    /// Hepburn rōmaji for Japanese words, so learners who can't read kana can still
    /// pronounce the word. Derived from the kana `reading` (or the headword itself
    /// when it's already kana). Nil for non-Japanese words or when the source has
    /// no romanizable kana.
    var romaji: String? {
        guard language == .japanese else { return nil }
        return KanaRomaji.romaji(from: reading ?? word)
    }

    /// Human-readable part of speech for display and export.
    var partOfSpeechLabel: String {
        switch pos {
        case "n":    return "noun"
        case "v":    return "verb"
        case "adj":  return "adjective"
        case "adv":  return "adverb"
        case "expr": return "expression"
        default:     return pos
        }
    }
}
