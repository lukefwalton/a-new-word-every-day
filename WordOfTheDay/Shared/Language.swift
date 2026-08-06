import Foundation

/// A learnable language: identity, corpus resource, level names, and how its
/// words render. Adding a language means one new case here plus a bundled
/// `words_<code>.json` built by scripts/build_corpus.py — everything else
/// (selection, calibration, per-language difficulty, widgets) keys off this.
enum Language: String, Codable, CaseIterable, Identifiable, Hashable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:  return "English"
        case .japanese: return "Japanese"
        }
    }

    /// The language's name in its own script, shown alongside `displayName`
    /// in pickers ("Japanese · 日本語").
    var nativeName: String {
        switch self {
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }

    /// Bundle resource (sans extension) of this language's corpus. English keeps
    /// the original bare "words" so existing installs load the same file.
    var corpusResource: String {
        self == .english ? "words" : "words_\(rawValue)"
    }

    /// Display names for this language's difficulty bands, index 0 = band 1.
    /// Japanese bands map one-to-one onto JLPT levels, which learners already
    /// know themselves by — so Japanese stops at five and English does not.
    var levelNames: [String] {
        switch self {
        case .english:  return ["Gentle", "Easy", "Medium", "Hard", "Rare", "Arcane"]
        case .japanese: return ["N5", "N4", "N3", "N2", "N1"]
        }
    }

    /// The hardest band this language has words for. Derived from `levelNames`
    /// so the two can never drift; everything that clamps a band (settings
    /// stepper, onboarding picker, `DifficultyModel`) keys off this.
    var maxBand: Int { levelNames.count }

    /// One-line descriptions for the self-assessment picker, same order as
    /// `levelNames`.
    var levelDescriptions: [String] {
        switch self {
        case .english: return [
            "Common but vivid words",
            "Familiar with a literary edge",
            "Words strong readers reach for",
            "Rarer, precise vocabulary",
            "The rare and the literary",
            "Beyond rare — the esoteric",
        ]
        case .japanese: return [
            "Beginner — everyday basics",
            "Upper beginner — daily life",
            "Intermediate — most conversation",
            "Upper intermediate — news and work",
            "Advanced — near-native range",
        ]
        }
    }

    func levelName(forBand band: Int) -> String {
        let names = levelNames
        return names[min(max(band - 1, 0), names.count - 1)]
    }
}

extension String {
    /// True when the string contains CJK ideographs or kana — used to route hero
    /// text to the system face (the bundled variable fonts are Latin-only).
    var containsCJK: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF,   // hiragana + katakana
                 0x3400...0x4DBF,   // CJK extension A
                 0x4E00...0x9FFF,   // CJK unified ideographs
                 0xF900...0xFAFF,   // CJK compatibility ideographs
                 0xFF66...0xFF9D:   // halfwidth katakana
                return true
            default:
                return false
            }
        }
    }
}
