import Foundation

/// Turns the onboarding swipe answers (and any in-app re-marking) into a single
/// difficulty `band`, entirely on-device. "Right = Know, Left = Don't know."
///
/// The band is the *hardest* level at which you still mostly know the words: we
/// walk from easiest (1) to hardest (maxBand) and keep raising the band while the
/// known-rate stays at or above `knownThreshold`, stopping at the first band that
/// falls below. This grounds the daily word at the edge of what you already know.
struct DifficultyModel {
    var maxBand: Int
    var knownThreshold: Double
    /// Band used before the user has answered anything — a gentle middle start.
    var defaultBand: Int

    init(maxBand: Int = 5, knownThreshold: Double = 0.6, defaultBand: Int = 2) {
        self.maxBand = maxBand
        self.knownThreshold = knownThreshold
        self.defaultBand = defaultBand
    }

    /// One swipe answer: the band of the shown word and whether the user knew it.
    struct Answer: Equatable {
        let band: Int
        let known: Bool
        init(band: Int, known: Bool) {
            self.band = band
            self.known = known
        }
    }

    /// The calibrated starting band from a set of answers.
    func calibratedBand(from answers: [Answer]) -> Int {
        guard !answers.isEmpty else { return defaultBand }

        var result = 1
        for band in 1...maxBand {
            let inBand = answers.filter { $0.band == band }
            guard !inBand.isEmpty else { continue } // no signal for this band; keep going
            let knownCount = inBand.filter { $0.known }.count
            let rate = Double(knownCount) / Double(inBand.count)
            if rate >= knownThreshold {
                result = band
            } else {
                break
            }
        }
        return min(max(result, 1), maxBand)
    }

    /// Nudge an existing band by one when the user marks a word in-app: knowing a
    /// word at your ceiling pushes you up; missing one at/below your level pulls
    /// you down. Clamped to [1, maxBand].
    func adjusted(band: Int, markedKnown known: Bool, wordBand: Int) -> Int {
        var band = band
        if known, wordBand >= band, band < maxBand {
            band += 1
        } else if !known, wordBand <= band, band > 1 {
            band -= 1
        }
        return min(max(band, 1), maxBand)
    }
}
