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

    static func word(_ id: Int, band: Int, word: String? = nil, pos: String = "adj") -> Word {
        Word(id: id, word: word ?? "word\(id)", pos: pos,
             definition: "definition \(id)", band: band)
    }

    /// `perBand` words in each of `bands` bands, ids 1…(perBand*bands).
    static func corpus(perBand: Int = 4, bands: Int = 5) -> [Word] {
        var out: [Word] = []
        var id = 1
        for band in 1...bands {
            for _ in 0..<perBand {
                out.append(word(id, band: band))
                id += 1
            }
        }
        return out
    }

    /// A `SharedStore` backed by a throwaway defaults suite (cleared on creation).
    static func volatileStore() -> SharedStore {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SharedStore(defaults: defaults)
    }
}
