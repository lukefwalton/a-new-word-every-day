import Foundation

/// The bundled, read-only word list. Loaded once from `words.json`, which is
/// compiled into both the app and the widget targets (so the widget needs no
/// database and no network). Decoupled from selection logic, which takes plain
/// `[Word]`, so it's trivial to test with fixtures.
struct WordCorpus {
    let words: [Word]
    let byID: [Int: Word]

    init(words: [Word]) {
        self.words = words
        self.byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func word(id: Int) -> Word? { byID[id] }

    /// Decode `words.json` from the given bundles (first hit wins). Searching a
    /// list lets the same loader serve the app, the widget, and the test bundle.
    static func load(bundles: [Bundle] = [.main]) -> WordCorpus {
        for bundle in bundles {
            guard let url = bundle.url(forResource: "words", withExtension: "json") else { continue }
            do {
                let data = try Data(contentsOf: url)
                let words = try JSONDecoder().decode([Word].self, from: data)
                if !words.isEmpty { return WordCorpus(words: words) }
            } catch {
                // Fall through to the next bundle; an empty corpus surfaces a
                // clear empty-state in the UI rather than crashing.
                continue
            }
        }
        return WordCorpus(words: [])
    }
}
