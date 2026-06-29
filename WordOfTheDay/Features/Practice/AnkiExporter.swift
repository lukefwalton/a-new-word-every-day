import Foundation

/// Exports starred words to a file Anki imports natively — plain tab-separated
/// text with `#`-directive headers (Anki 2.1.54+). This needs **no** Anki code
/// and therefore no AGPL exposure; it's just string building. The `#deck`,
/// `#notetype`, and `#tags` directives make the import one click.
enum AnkiExporter {
    static func tsv(for words: [Word],
                    deck: String = "Word of the Day",
                    tags: [String] = ["wordoftheday", "starred"]) -> String {
        var lines: [String] = [
            "#separator:tab",
            "#html:false",
            "#notetype:Basic",
            "#deck:\(deck)",
            "#tags:\(tags.joined(separator: " "))",
            "#columns:Front\tBack",
        ]
        for word in words {
            let back = "(\(word.partOfSpeechLabel)) \(word.definition)"
            lines.append("\(field(word.word))\t\(field(back))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Sanitize a field for tab-separated import: tabs and newlines would break
    /// the row/column structure, so collapse them to spaces.
    private static func field(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
