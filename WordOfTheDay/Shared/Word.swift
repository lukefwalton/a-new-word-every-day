import Foundation

/// One vocabulary entry. Matches the JSON produced by scripts/build_corpus.py.
/// Value type, Codable, deterministic — the whole app
/// and widget reason over arrays of these.
struct Word: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let word: String
    /// "n" | "v" | "adj" | "adv".
    let pos: String
    let definition: String
    /// Difficulty band, 1 (most accessible) … 5 (rarest/hardest).
    let band: Int

    /// Human-readable part of speech for display and export.
    var partOfSpeechLabel: String {
        switch pos {
        case "n":   return "noun"
        case "v":   return "verb"
        case "adj": return "adjective"
        case "adv": return "adverb"
        default:    return pos
        }
    }
}
