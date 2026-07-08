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

/// Every bundled corpus, one per supported language. Corpora decode lazily on
/// first access and are cached: the widget extension (which lives under a tight
/// memory ceiling and renders exactly one language per widget) never pays for
/// languages it doesn't show. Cross-language lookups (starred words, deep
/// links) search all corpora by id.
final class CorpusLibrary {
    private let bundles: [Bundle]
    private var cache: [Language: WordCorpus]
    private let lock = NSLock()

    /// Lazy-loading library over the given bundles (the production path).
    init(bundles: [Bundle] = [.main]) {
        self.bundles = bundles
        self.cache = [:]
    }

    /// Fully preloaded library — for tests and fixtures. Languages absent from
    /// `corpora` stay empty rather than hitting any bundle.
    init(corpora: [Language: WordCorpus]) {
        self.bundles = []
        self.cache = corpora
        for language in Language.allCases where corpora[language] == nil {
            cache[language] = WordCorpus(words: [])
        }
    }

    func corpus(for language: Language) -> WordCorpus {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[language] { return cached }
        let corpus = WordCorpus.load(language: language, bundles: bundles)
        cache[language] = corpus
        return corpus
    }

    /// Look up a word by id across all languages. Ids are hash-derived and
    /// salted per language at build time, so they never collide in practice.
    func word(id: Int) -> Word? {
        for language in Language.allCases {
            if let word = corpus(for: language).byID[id] { return word }
        }
        return nil
    }

    static func load(bundles: [Bundle] = [.main]) -> CorpusLibrary {
        CorpusLibrary(bundles: bundles)
    }
}
