import Foundation
import XCTest
@testable import WordOfTheDay

/// Shared builders for the test suite. Pure value fixtures + a volatile store so
/// nothing touches the real App Group container.
enum Fixtures {
    /// A fixed UTC Gregorian calendar so date math in tests is timezone-stable.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func word(_ id: Int, band: Int, word: String? = nil, pos: String = "adj",
                     reading: String? = nil, lang: String? = nil) -> Word {
        Word(id: id, word: word ?? "word\(id)", pos: pos,
             definition: "definition \(id)", band: band, reading: reading, lang: lang)
    }

    /// `perBand` words in each of `bands` bands, ids from `startID` up.
    static func corpus(perBand: Int = 4, bands: Int = 5, startID: Int = 1, lang: String? = nil) -> [Word] {
        var out: [Word] = []
        var id = startID
        for band in 1...bands {
            for _ in 0..<perBand {
                out.append(word(id, band: band, lang: lang))
                id += 1
            }
        }
        return out
    }

    /// A single-language (English) library over `words` — what most tests need.
    static func library(_ words: [Word]? = nil) -> CorpusLibrary {
        CorpusLibrary(corpora: [.english: WordCorpus(words: words ?? corpus())])
    }

    /// The standard test service over an English fixture corpus.
    static func service(_ words: [Word]? = nil) -> DailyWordService {
        DailyWordService(library: library(words),
                         selector: DailySelector(calendar: utc))
    }

    /// A `SharedStore` backed by a throwaway defaults suite (cleared on creation).
    static func volatileStore() -> SharedStore {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SharedStore(defaults: defaults)
    }
}
