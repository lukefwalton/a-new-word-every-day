import Foundation

/// Composes the corpus library, the deterministic selector, and the shared store
/// into the handful of questions the app and widget actually ask: what's today's
/// word (per language), what are the starred words, look up by id. Pure read
/// side — no writes.
struct DailyWordService {
    let library: CorpusLibrary
    let selector: DailySelector

    init(library: CorpusLibrary, selector: DailySelector = DailySelector()) {
        self.library = library
        self.selector = selector
    }

    /// Today's word for this install + language + that language's band. `now` is
    /// injectable for tests and for the widget timeline (which asks for several
    /// dates ahead). One shared install salt drives every language; the corpora
    /// are disjoint, so the shuffled orders are independent anyway.
    func todaysWord(store: SharedStore, language: Language, now: Date = Date()) -> Word? {
        selector.word(on: now,
                      installDate: store.installDate,
                      salt: store.installSalt,
                      band: store.band(for: language),
                      corpus: library.corpus(for: language).words)
    }

    /// Today's words across the user's enabled languages, in their enabled order.
    func todaysWords(store: SharedStore, now: Date = Date()) -> [Word] {
        store.enabledLanguages.compactMap { todaysWord(store: store, language: $0, now: now) }
    }

    /// The next word to explore in-app from a language's band — the "keep going"
    /// word behind Today's mark buttons — given every id the session has already
    /// shown (`seen`). A stable shuffle of the eligible pool, so the progression is
    /// deterministic per install and never repeats within the pool. Returns nil
    /// once the band is exhausted.
    ///
    /// Seeded in a namespace disjoint from the daily selector's, so exploring
    /// neither consumes nor collides with the canonical word-of-the-day sequence
    /// the widget shows — the two stay independent.
    func explorationWord(store: SharedStore, language: Language, seen: Set<Int>) -> Word? {
        let band = store.band(for: language)
        let pool = selector.eligible(in: library.corpus(for: language).words, band: band)
            .sorted { $0.id < $1.id }
            .seededShuffled(seed: Self.explorationSeed(salt: store.installSalt, band: band))
        return pool.first { !seen.contains($0.id) }
    }

    /// Exploration order seed. XOR-folds a fixed constant into the install salt so
    /// this ordering can never coincide with a daily cycle seed (`salt &+ cycle`).
    private static func explorationSeed(salt: UInt64, band: Int) -> UInt64 {
        (salt ^ 0xA5A5_5A5A_C3C3_3C3C) &+ UInt64(band)
    }

    func word(id: Int) -> Word? { library.word(id: id) }

    /// Starred words, newest first, skipping any ids no longer in the corpora.
    func starredWords(store: SharedStore) -> [Word] {
        store.starredIDs.compactMap { library.word(id: $0) }
    }

    /// A sample of one language's words spread across difficulty bands — the deck
    /// the onboarding swipe step calibrates on. Deterministic per salt so a
    /// restart is stable. `perBand` × band-count is the deck size (3 × 5 = 15) —
    /// enough per band for a stable known-rate without a long swipe chore.
    func calibrationSample(language: Language, perBand: Int = 3, salt: UInt64) -> [Word] {
        var picked: [Word] = []
        let byBand = Dictionary(grouping: library.corpus(for: language).words, by: { $0.band })
        for band in byBand.keys.sorted() {
            let pool = (byBand[band] ?? []).sorted { $0.id < $1.id }.seededShuffled(seed: salt &+ UInt64(band))
            picked.append(contentsOf: pool.prefix(perBand))
        }
        return picked.seededShuffled(seed: salt)
    }
}
