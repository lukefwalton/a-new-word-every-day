import Foundation

/// A deterministic pseudo-random generator (SplitMix64). Given the same seed it
/// always produces the same sequence — which is exactly what the daily word
/// selection needs so the app and the widget compute byte-identical results
/// without sharing any written state. Never use the system RNG for selection.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension Array {
    /// A deterministic shuffle keyed on `seed` (seeded Fisher–Yates). Same seed +
    /// same elements ⇒ same order, on every device and process.
    func seededShuffled(seed: UInt64) -> [Element] {
        var rng = SeededRandom(seed: seed)
        var result = self
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }
}
