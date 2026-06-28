import Foundation

/// Per-word review state, shaped to match FSRS so that adopting a real scheduler
/// later (e.g. the MIT `open-spaced-repetition/swift-fsrs`) is a swap, not a data
/// migration. FSRS is a superset of SM-2, so the simple scheduler below can drive
/// these same fields today. Nothing here is wired into the UI yet — it's the seam
/// the spec promised, with tests, so "someday Anki / in-app practice" is cheap.
struct ReviewState: Codable, Equatable {
    var stability: Double
    var difficulty: Double
    var reps: Int
    var lapses: Int
    var intervalDays: Int
    var lastReviewed: Date?
    var due: Date?

    init(stability: Double = 0, difficulty: Double = 5, reps: Int = 0, lapses: Int = 0,
         intervalDays: Int = 0, lastReviewed: Date? = nil, due: Date? = nil) {
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.intervalDays = intervalDays
        self.lastReviewed = lastReviewed
        self.due = due
    }
}

enum ReviewGrade: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// A minimal SM-2-style scheduler. Deterministic and tiny; the attribution below
/// is the only obligation for the published SM-2 algorithm.
///
/// Algorithm SM-2, (C) Copyright SuperMemo World, 1991.
enum SM2Scheduler {
    /// Advance review state for a grade, computing the next interval and due date.
    static func review(_ state: ReviewState, grade: ReviewGrade, now: Date,
                       calendar: Calendar = .current) -> ReviewState {
        var next = state
        next.lastReviewed = now
        next.reps += 1

        if grade == .again {
            next.lapses += 1
            next.reps = 0
            next.intervalDays = 1
        } else {
            switch next.reps {
            case 1:  next.intervalDays = 1
            case 2:  next.intervalDays = 6
            default:
                let ease = easeFactor(difficulty: next.difficulty)
                next.intervalDays = max(1, Int((Double(state.intervalDays) * ease).rounded()))
            }
        }

        // Difficulty drifts easier/harder within [1, 10]; mirrors FSRS' direction
        // so the field stays meaningful when we switch schedulers.
        let delta: Double = grade == .easy ? -0.6 : grade == .good ? -0.1 : grade == .hard ? 0.3 : 0.8
        next.difficulty = min(max(next.difficulty + delta, 1), 10)
        next.stability = Double(next.intervalDays)
        next.due = calendar.date(byAdding: .day, value: next.intervalDays, to: now)
        return next
    }

    /// SM-2 ease factor derived from our 1…10 difficulty (10 = hardest → 1.3 floor).
    private static func easeFactor(difficulty: Double) -> Double {
        // Map difficulty 1→2.5 (easy, long intervals) … 10→1.3 (hard, short).
        let normalized = (10 - difficulty) / 9 // 1 at easiest, 0 at hardest
        return 1.3 + normalized * (2.5 - 1.3)
    }
}
