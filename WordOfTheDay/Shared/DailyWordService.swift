import Foundation

/// Composes the corpus, the deterministic selector, and the shared store into the
/// handful of questions the app and widget actually ask: what's today's word,
/// what are the starred words, look up by id. Pure read side — no writes.
struct DailyWordService {
    let corpus: WordCorpus
    let selector: DailySelector

    init(corpus: WordCorpus, selector: DailySelector = DailySelector()) {
        self.corpus = corpus
        self.selector = selector
    }

    /// Today's word for this install + band. `now` is injectable for tests and
    /// for the widget timeline (which asks for several dates ahead).
    func todaysWord(store: SharedStore, now: Date = Date()) -> Word? {
        selector.word(on: now,
                      installDate: store.installDate,
                      salt: store.installSalt,
                      band: store.band,
                      corpus: corpus.words)
    }

    func word(id: Int) -> Word? { corpus.word(id: id) }

    /// Starred words, newest first, skipping any ids no longer in the corpus.
    func starredWords(store: SharedStore) -> [Word] {
        store.starredIDs.compactMap { corpus.word(id: $0) }
    }

    /// A sample of words spread across difficulty bands — the deck the onboarding
    /// swipe step calibrates on. Deterministic per salt so a restart is stable.
    func calibrationSample(perBand: Int = 5, salt: UInt64) -> [Word] {
        var picked: [Word] = []
        let byBand = Dictionary(grouping: corpus.words, by: { $0.band })
        for band in byBand.keys.sorted() {
            let pool = (byBand[band] ?? []).sorted { $0.id < $1.id }.seededShuffled(seed: salt &+ UInt64(band))
            picked.append(contentsOf: pool.prefix(perBand))
        }
        return picked.seededShuffled(seed: salt)
    }
}
