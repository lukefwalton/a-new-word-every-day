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
    func word(on date: Date, installDate: Date, salt: UInt64, band: Int, corpus: [Word]) -> Word? {
        // Stable base order (by id) so the result is independent of how the
        // corpus array happened to be ordered when loaded.
        let pool = eligible(in: corpus, band: band).sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }
        let order = pool.seededShuffled(seed: salt)
        let index = dayIndex(installDate: installDate, on: date) % order.count
        return order[index]
    }
}
