import Foundation

/// Picks the word of the day as a pure function of (date, install seed, band,
/// corpus). No stored "today's word" — the widget recomputes the same answer the
/// app shows, so they never disagree and nothing needs writing at midnight.
struct DailySelector {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Words the user is eligible to see: at or below their band. Falls back to
    /// the whole corpus if a band filter would leave nothing (defensive).
    func eligible(in corpus: [Word], band: Int) -> [Word] {
        let pool = corpus.filter { $0.band <= band }
        return pool.isEmpty ? corpus : pool
    }

    /// Whole days from install to `date` (clamped at 0). The integer cursor into
    /// the shuffled pool.
    func dayIndex(installDate: Date, on date: Date) -> Int {
        let start = calendar.startOfDay(for: installDate)
        let day = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        return max(0, days)
    }

    /// The word for `date`. `salt` is the per-install seed; `band` filters the
    /// pool. Returns nil only for an empty corpus.
    ///
    /// Once every word has been shown (`pool.count` days), the pool reshuffles
    /// with a fresh per-cycle seed instead of replaying the same order — still a
    /// pure function of the same inputs, so the widget stays in lockstep. Cycle 0
    /// uses `salt` unchanged, byte-identical to the pre-reshuffle behavior.
    func word(on date: Date, installDate: Date, salt: UInt64, band: Int, corpus: [Word]) -> Word? {
        // Stable base order (by id) so the result is independent of how the
        // corpus array happened to be ordered when loaded.
        let pool = eligible(in: corpus, band: band).sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }
        let day = dayIndex(installDate: installDate, on: date)
        let cycle = day / pool.count
        let index = day % pool.count
        var order = pool.seededShuffled(seed: Self.cycleSeed(salt: salt, cycle: cycle))
        // Boundary guard: if this cycle would open with the word the previous
        // cycle closed with, swap the first two slots. The swap is a property of
        // the whole cycle (every day recomputes it identically), and it never
        // touches the last slot when the pool has 3+ words, so the previous
        // cycle's raw shuffle order is authoritative for its own last word.
        // Pools of 1–2 are degenerate (the real corpus has 219+ per band).
        if cycle > 0, pool.count > 2,
           let prevLast = pool.seededShuffled(seed: Self.cycleSeed(salt: salt, cycle: cycle - 1)).last,
           order[0].id == prevLast.id {
            order.swapAt(0, 1)
        }
        return order[index]
    }

    /// Seed for one full pass through the pool. SplitMix64 fully mixes
    /// sequential seeds, so `salt`, `salt + 1`, … give independent orders;
    /// cycle 0 is `salt` itself, preserving the original first-pass order.
    ///
    /// `cycle` derives from `pool.count`, which depends on `band`, so past the
    /// first pass a band change can move the cycle (and thus this seed). That's
    /// not new instability — a band change already reshuffles the whole pool
    /// (different membership/size ⇒ different order); `band` is still not an
    /// explicit seed input, and cycle 0 is unaffected. (SPEC §3.3.)
    private static func cycleSeed(salt: UInt64, cycle: Int) -> UInt64 {
        salt &+ UInt64(cycle)
    }
}
