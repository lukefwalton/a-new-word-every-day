import Foundation

/// Deterministic kana → Hepburn rōmaji transliteration, so learners who can't yet
/// read kana can still pronounce a Japanese word. Pure and table-driven; handles
/// hiragana + katakana, youon (きゃ→kya), sokuon (っ→doubled consonant), the
/// katakana long-vowel mark (ー), syllabic ん (→ n / n'), and common loanword
/// combos (ティ→ti, ファ→fa, シェ→she). Not a full linguistic romanizer — it aims
/// to be right for the JLPT vocabulary this app ships.
enum KanaRomaji {
    /// Rōmaji for a kana string, or nil if it isn't romanizable (e.g. it still
    /// contains kanji — callers should pass a kana `reading`, not a kanji headword).
    static func romaji(from raw: String) -> String? {
        // Needs real kana to romanize, and can't handle kanji (callers should pass
        // a kana reading). Both guards keep non-Japanese input from passing through.
        guard !raw.isEmpty, containsKana(raw), !containsKanji(raw) else { return nil }
        let kana = Array(toHiragana(raw))
        var out = ""
        var i = 0
        var geminate = false

        while i < kana.count {
            let c = kana[i]

            if c == "ー" {                                    // long-vowel mark
                if let last = out.last, "aeiou".contains(last) { out.append(last) }
                i += 1
                continue
            }
            if c == "っ" {                                    // sokuon → double next
                geminate = true
                i += 1
                continue
            }
            if c == "ん" {                                    // syllabic n
                // n' before a vowel or y so ん+や reads "n'ya", not "nya".
                var n = "n"
                if i + 1 < kana.count, let next = syllable(kana, i + 1)?.0.first,
                   "aeiouy".contains(next) {
                    n = "n'"
                }
                out += n
                i += 1
                continue
            }

            guard let (rom, len) = syllable(kana, i) else {    // unknown — pass through
                out.append(c)
                i += 1
                continue
            }

            var mapped = rom
            if geminate {
                geminate = false
                // Hepburn geminates ち-row as "tch" (っち → tchi), else doubles the
                // leading consonant (っか → kka). Vowel-initial syllables can't
                // geminate, so leave those alone.
                if mapped.hasPrefix("ch") {
                    mapped = "t" + mapped
                } else if let first = mapped.first, !"aeiou".contains(first) {
                    mapped = String(first) + mapped
                }
            }
            out += mapped
            i += len
        }
        return out.isEmpty ? nil : out
    }

    // MARK: Matching

    /// Rōmaji + kana consumed for the syllable at `i`, preferring a two-kana youon
    /// / loanword combo before a single base kana.
    private static func syllable(_ kana: [Character], _ i: Int) -> (String, Int)? {
        if i + 1 < kana.count {
            let pair = String(kana[i]) + String(kana[i + 1])
            if let r = digraphs[pair] { return (r, 2) }
        }
        if let r = monographs[kana[i]] { return (r, 1) }
        return nil
    }

    // MARK: Normalisation

    /// Fold katakana onto hiragana (they romanize identically), keeping the
    /// long-vowel mark ー and passing anything else through untouched.
    private static func toHiragana(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if u.value == 0x30FC {                             // ー stays as-is
                out.append(u)
            } else if (0x30A1...0x30F6).contains(u.value),     // katakana → hiragana
                      let shifted = Unicode.Scalar(u.value - 0x60) {
                out.append(shifted)
            } else {
                out.append(u)
            }
        }
        return String(out)
    }

    private static func containsKanji(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
    }

    private static func containsKana(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x3041...0x3096).contains($0.value) || (0x30A1...0x30FA).contains($0.value) }
    }

    // MARK: Tables

    private static let monographs: [Character: String] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "ゐ": "wi", "ゑ": "we", "を": "o", "ん": "n",
        "ゔ": "vu",
        // Small kana standing alone (rare, but keep them readable).
        "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
        "ゃ": "ya", "ゅ": "yu", "ょ": "yo", "っ": "",
    ]

    private static let digraphs: [String: String] = [
        "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
        "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
        "しゃ": "sha", "しゅ": "shu", "しょ": "sho", "しぇ": "she",
        "じゃ": "ja", "じゅ": "ju", "じょ": "jo", "じぇ": "je",
        "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho", "ちぇ": "che",
        "ぢゃ": "ja", "ぢゅ": "ju", "ぢょ": "jo",
        "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
        "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
        "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
        "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
        "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
        "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
        // Loanword combos common in the katakana vocabulary.
        "ふぁ": "fa", "ふぃ": "fi", "ふぇ": "fe", "ふぉ": "fo", "ふゅ": "fyu",
        "ゔぁ": "va", "ゔぃ": "vi", "ゔぇ": "ve", "ゔぉ": "vo",
        "てぃ": "ti", "でぃ": "di", "とぅ": "tu", "どぅ": "du",
        "つぁ": "tsa", "つぃ": "tsi", "つぇ": "tse", "つぉ": "tso",
        "うぃ": "wi", "うぇ": "we", "うぉ": "wo",
    ]
}
