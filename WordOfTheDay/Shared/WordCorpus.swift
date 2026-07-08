import Foundation

/// One language's bundled, read-only word list. Loaded from that language's
/// `words*.json`, which is compiled into both the app and the widget targets
/// (so the widget needs no database and no network). Decoupled from selection
/// logic, which takes plain `[Word]`, so it's trivial to test with fixtures.
struct WordCorpus {
    let words: [Word]
    let byID: [Int: Word]

    init(words: [Word]) {
        self.words = words
        self.byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func word(id: Int) -> Word? { byID[id] }

    /// Decode a language's corpus from the given bundles (first hit wins).
    /// Searching a list lets the same loader serve the app, the widget, and the
    /// test bundle.
    static func load(language: Language = .english, bundles: [Bundle] = [.main]) -> WordCorpus {
        for bundle in bundles {
            guard let url = bundle.url(forResource: language.corpusResource, withExtension: "json") else { continue }
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

/// Every bundled corpus, one per supported language. The app and widget load
/// this once; per-language features index into it, and cross-language lookups
/// (starred words, deep links) search all corpora by id.
struct CorpusLibrary {
    let corpora: [Language: WordCorpus]

    init(corpora: [Language: WordCorpus]) {
        self.corpora = corpora
    }

    func corpus(for language: Language) -> WordCorpus {
        corpora[language] ?? WordCorpus(words: [])
    }

    /// Look up a word by id across all languages. Ids are hash-derived and
    /// salted per language at build time, so they never collide in practice.
    func word(id: Int) -> Word? {
        for language in Language.allCases {
            if let word = corpora[language]?.byID[id] { return word }
        }
        return nil
    }

    var isEmpty: Bool { corpora.values.allSatisfy { $0.words.isEmpty } }

    static func load(bundles: [Bundle] = [.main]) -> CorpusLibrary {
        CorpusLibrary(corpora: Dictionary(uniqueKeysWithValues: Language.allCases.map {
            ($0, WordCorpus.load(language: $0, bundles: bundles))
        }))
    }
}
