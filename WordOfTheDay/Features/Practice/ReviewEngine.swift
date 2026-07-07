import Foundation

/// The in-app spaced-repetition scheduler — a self-contained port of the FSRS-6
/// algorithm. It's re-implemented here rather than taken as a dependency so the
/// repo stays dependency-free (and on Xcode 15 / Swift 5) while staying faithful
/// to FSRS.
///
/// This is the single scheduling boundary: the persisted model (`ReviewState`),
/// the store, and the UI never reach past the small surface below — so swapping
/// the algorithm again would touch only this file.
///
/// Algorithm: FSRS-6, ported from open-spaced-repetition/py-fsrs v6.3.1
/// (MIT License). Intervals are whole days (no sub-day learning steps); a
/// same-day regrade uses FSRS-6's short-term stability formula. Runs entirely
/// on-device; no review data leaves the phone.
struct ReviewEngine {
    /// FSRS-6 default parameters (21), verbatim from py-fsrs `DEFAULT_PARAMETERS`.
    private static let w: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722,
        0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
        0.0912, 0.0658, 0.1542,
    ]
    /// FSRS-6 makes the forgetting-curve decay a fitted parameter (−w[20])
    /// rather than the fixed −0.5 of FSRS-4/5.
    private static let decay = -w[20]
    private static let factor = pow(0.9, 1 / decay) - 1
    private static let requestRetention = 0.9
    private static let maximumInterval = 36_500.0
    private static let minimumStability = 0.001

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
        var next = projected(state, grade, now: now)
        let interval = nextInterval(stability: next.stability, fuzz: enableFuzz)
        next.scheduledDays = Double(interval)
        next.due = Self.add(days: interval, to: now)
        return next
    }

    /// The next-review interval (in **whole days**) each grade would schedule from
    /// the card's current state, computed *without* fuzz so it's stable and exactly
    /// reproducible. The study UI shows these under the grade buttons ("Good · 3d")
    /// so the schedule is visible before the user commits. A `nil` state previews a
    /// brand-new card. No side effects.
    func preview(_ state: ReviewState?, now: Date = Date()) -> [ReviewGrade: Int] {
        var intervals: [ReviewGrade: Int] = [:]
        for grade in ReviewGrade.allCases {
            let outcome = projected(state, grade, now: now)
            intervals[grade] = nextInterval(stability: outcome.stability, fuzz: false)
        }
        return intervals
    }

    /// The post-review FSRS state (difficulty, stability, reps, lapses, …) for a
    /// grade — everything *except* the interval-derived `scheduledDays`/`due`, which
    /// `grade()` and `preview()` apply differently (real fuzz vs none). Pure; the
    /// single place the DSR update lives, so the committed schedule and the previewed
    /// one can never drift.
    private func projected(_ state: ReviewState?, _ grade: ReviewGrade, now: Date) -> ReviewState {
        var next = state ?? ReviewState(due: now)
        let g = Double(grade.rawValue)            // again=1 … easy=4

        if let last = state, let lastReview = last.lastReview {
            // Subsequent review: update difficulty/stability from recall performance.
            let elapsed = max(0, Self.days(from: lastReview, to: now))
            next.elapsedDays = elapsed
            next.difficulty = Self.nextDifficulty(last.difficulty, g)
            if elapsed < 1 {
                // Same-day regrade (the in-session Again requeue lands here):
                // FSRS-6's short-term stability formula, no retrievability input.
                next.stability = Self.shortTermStability(s: last.stability, g: g)
            } else {
                let r = Self.forgettingCurve(elapsed: elapsed, stability: last.stability)
                next.stability = grade == .again
                    ? Self.nextForgetStability(d: last.difficulty, s: last.stability, r: r)
                    : Self.nextRecallStability(d: last.difficulty, s: last.stability, r: r, grade: grade)
            }
            // A lapse is forgetting an already-learned card, so it counts only on a
            // *subsequent* Again — never on a first review of a brand-new card.
            if grade == .again { next.lapses += 1 }
        } else {
            // First review: seed difficulty/stability from the grade alone. Failing a
            // never-learned card is not a lapse.
            next.elapsedDays = 0
            next.difficulty = Self.initDifficulty(g)
            next.stability = Self.initStability(grade)
        }

        next.stability = max(Self.minimumStability, next.stability)
        next.reps += 1
        // The long-term scheduler has no learning steps, so cards are always in the
        // Review state.
        next.state = 2
        next.lastReview = now
        return next
    }

    // MARK: - FSRS-6 math (ported from py-fsrs, MIT)

    private static func initStability(_ grade: ReviewGrade) -> Double {
        max(w[grade.rawValue - 1], minimumStability)
    }

    /// D0(g) without the [1, 10] clamp — the mean-reversion target uses the raw
    /// value (D0(4) ≈ −4.77 with default weights), per py-fsrs.
    private static func rawInitDifficulty(_ g: Double) -> Double {
        w[4] - exp((g - 1) * w[5]) + 1
    }

    private static func initDifficulty(_ g: Double) -> Double {
        constrainDifficulty(rawInitDifficulty(g))
    }

    private static func constrainDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }

    private static func forgettingCurve(elapsed: Double, stability: Double) -> Double {
        pow(1 + factor * elapsed / stability, decay)
    }

    /// Pull `current` toward the raw Easy initial difficulty (mean reversion),
    /// weighted by w[7].
    private static func meanReversion(_ initValue: Double, _ current: Double) -> Double {
        w[7] * initValue + (1 - w[7]) * current
    }

    private static func nextDifficulty(_ d: Double, _ g: Double) -> Double {
        // FSRS-6 damps the difficulty delta linearly as D approaches 10, so
        // difficulty saturates instead of pinning at the clamp.
        let deltaD = -w[6] * (g - 3)
        let damped = d + deltaD * (10 - d) / 9
        return constrainDifficulty(meanReversion(rawInitDifficulty(4), damped))
    }

    private static func nextRecallStability(d: Double, s: Double, r: Double, grade: ReviewGrade) -> Double {
        let hardPenalty = grade == .hard ? w[15] : 1.0
        let easyBonus = grade == .easy ? w[16] : 1.0
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9])
            * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
    }

    private static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        // FSRS-6 caps post-lapse stability so a forget can never *raise* S past
        // what a same-day Again would leave (s / e^(w17·w18)).
        min(w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14]),
            s / exp(w[17] * w[18]))
    }

    /// FSRS-6 short-term stability, used when the previous review was less than a
    /// day ago. Successful grades (Good/Easy) never shrink stability.
    private static func shortTermStability(s: Double, g: Double) -> Double {
        var sInc = exp(w[17] * (g - 3 + w[18])) * pow(s, -w[19])
        if g >= 3 { sInc = max(sInc, 1) }
        return s * sInc
    }

    /// FSRS-6 interval from stability, in **whole days** — this is the long-term
    /// variant, intentionally with no sub-day learning steps. Same-session
    /// relearning of a failed card is handled by `ReviewQueue` (it re-shows the
    /// card) plus the short-term stability formula above; that's the deliberate
    /// "lightweight" behaviour for this app.
    private func nextInterval(stability: Double, fuzz: Bool) -> Int {
        let modifier = (pow(Self.requestRetention, 1 / Self.decay) - 1) / Self.factor
        var ivl = min(max(1, (stability * modifier).rounded()), Self.maximumInterval)
        if fuzz { ivl = Self.fuzz(ivl) }
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
