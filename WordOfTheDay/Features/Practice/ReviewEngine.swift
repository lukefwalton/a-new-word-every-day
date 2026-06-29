import Foundation

/// The in-app spaced-repetition scheduler — a self-contained port of the FSRS-5
/// algorithm (long-term variant). It's re-implemented here rather than taken as a
/// dependency: `open-spaced-repetition/swift-fsrs` exposes its types `public` but
/// its initializers and methods `internal`, so it can't be called from another
/// module. Porting the math keeps the repo dependency-free (and on Xcode 15 /
/// Swift 5) while staying faithful to FSRS.
///
/// This is the single scheduling boundary: the persisted model (`ReviewState`),
/// the store, and the UI never reach past the small surface below — so swapping
/// the algorithm again would touch only this file.
///
/// Algorithm: FSRS-5, ported from open-spaced-repetition/swift-fsrs (MIT License).
/// Runs entirely on-device; no review data leaves the phone.
struct ReviewEngine {
    /// FSRS-5 default weights (19), verbatim from swift-fsrs `FSRSDefaults.defaultW`.
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616,
        0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466, 0.5034, 0.6567,
    ]
    private static let decay = -0.5
    private static let factor = 19.0 / 81.0          // 0.9^(1/decay) - 1
    private static let requestRetention = 0.9
    private static let maximumInterval = 36_500.0
    private static let minimumStability = 0.1

    /// FSRS spreads long intervals by a small random band so a day's reviews don't
    /// all fall due together. Tests pass `false` for deterministic intervals.
    private let enableFuzz: Bool

    init(enableFuzz: Bool = true) {
        self.enableFuzz = enableFuzz
    }

    /// A brand-new, never-reviewed card, due immediately.
    func newState(now: Date = Date()) -> ReviewState {
        ReviewState(due: now)
    }

    /// Whether a word is ready to study now: never-reviewed cards (`nil`) are due,
    /// otherwise it's due once `now` reaches the scheduled date.
    func isDue(_ state: ReviewState?, now: Date = Date()) -> Bool {
        guard let due = state?.due else { return true }
        return due <= now
    }

    /// Advance a word's schedule for a recall grade. `nil` means the word has never
    /// been reviewed (a fresh card). Total function — out-of-range values are
    /// clamped, so there's no failure mode to surface.
    func grade(_ state: ReviewState?, _ grade: ReviewGrade, now: Date = Date()) -> ReviewState {
        var next = state ?? ReviewState(due: now)
        let g = Double(grade.rawValue)            // again=1 … easy=4

        if let last = state, let lastReview = last.lastReview {
            // Subsequent review: update difficulty/stability from recall performance.
            let elapsed = max(0, Self.days(from: lastReview, to: now))
            let r = Self.forgettingCurve(elapsed: elapsed, stability: last.stability)
            next.elapsedDays = elapsed
            next.difficulty = Self.nextDifficulty(last.difficulty, g)
            next.stability = grade == .again
                ? Self.nextForgetStability(d: last.difficulty, s: last.stability, r: r)
                : Self.nextRecallStability(d: last.difficulty, s: last.stability, r: r, grade: grade)
        } else {
            // First review: seed difficulty/stability from the grade alone.
            next.elapsedDays = 0
            next.difficulty = Self.initDifficulty(g)
            next.stability = Self.initStability(grade)
        }

        next.stability = max(Self.minimumStability, next.stability)
        let interval = nextInterval(stability: next.stability)
        next.scheduledDays = Double(interval)
        next.reps += 1
        if grade == .again { next.lapses += 1 }
        next.state = grade == .again ? 3 : 2      // relearning : review
        next.lastReview = now
        next.due = Self.add(days: interval, to: now)
        return next
    }

    // MARK: - FSRS-5 math (ported from swift-fsrs, MIT)

    private static func initStability(_ grade: ReviewGrade) -> Double {
        max(w[grade.rawValue - 1], minimumStability)
    }

    private static func initDifficulty(_ g: Double) -> Double {
        constrainDifficulty(w[4] - exp((g - 1) * w[5]) + 1)
    }

    private static func constrainDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }

    private static func forgettingCurve(elapsed: Double, stability: Double) -> Double {
        pow(1 + factor * elapsed / stability, decay)
    }

    /// Pull `current` toward `initValue` (mean reversion), weighted by w[7].
    private static func meanReversion(_ initValue: Double, _ current: Double) -> Double {
        w[7] * initValue + (1 - w[7]) * current
    }

    private static func nextDifficulty(_ d: Double, _ g: Double) -> Double {
        let nextD = d - w[6] * (g - 3)
        return constrainDifficulty(meanReversion(initDifficulty(4), nextD))
    }

    private static func nextRecallStability(d: Double, s: Double, r: Double, grade: ReviewGrade) -> Double {
        let hardPenalty = grade == .hard ? w[15] : 1.0
        let easyBonus = grade == .easy ? w[16] : 1.0
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9])
            * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
    }

    private static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
    }

    /// FSRS-5 interval from stability, in **whole days** — this is the long-term
    /// variant, intentionally with no sub-day learning steps. Same-session
    /// relearning of a failed card is handled by `ReviewQueue` (it re-shows the
    /// card), not by minute-level scheduler steps; that's the deliberate
    /// "lightweight" behaviour for this app.
    private func nextInterval(stability: Double) -> Int {
        let modifier = (pow(Self.requestRetention, 1 / Self.decay) - 1) / Self.factor
        var ivl = min(max(1, (stability * modifier).rounded()), Self.maximumInterval)
        if enableFuzz { ivl = Self.fuzz(ivl) }
        return Int(ivl)
    }

    // MARK: - Helpers

    /// A small random ± band on longer intervals (FSRS fuzz) so due dates spread
    /// out. Short intervals are left exact. Randomness here only affects *when* a
    /// review lands, never which word (that stays deterministic elsewhere).
    private static func fuzz(_ interval: Double) -> Double {
        guard interval >= 2.5 else { return interval }
        let delta = max(1.0, interval * 0.05)
        let low = Int(max(2.0, (interval - delta).rounded()))
        let high = Int(min(maximumInterval, (interval + delta).rounded()))
        guard low < high else { return interval }
        return Double(Int.random(in: low...high))
    }

    private static func days(from start: Date, to end: Date) -> Double {
        end.timeIntervalSince(start) / 86_400
    }

    private static func add(days: Int, to date: Date) -> Date {
        date.addingTimeInterval(Double(days) * 86_400)
    }
}
