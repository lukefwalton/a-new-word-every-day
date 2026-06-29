import Foundation

/// Per-word review schedule — a neutral, `Codable` mirror of the FSRS `Card`
/// (open-spaced-repetition/swift-fsrs, pinned at v5.0.0). Keeping our own copy of
/// the fields means the *persisted* shape never imports the scheduler package: the
/// app and the widget both compile this type, but only `ReviewEngine` (app target)
/// ever touches `FSRS`. Swapping schedulers later stays a one-file change there —
/// not a data migration here.
///
/// Field names and defaults match `Card` 1:1 so the `ReviewEngine` conversion is
/// trivial and lossless. (`state` is stored as the `CardState` raw value to keep
/// this file free of any `FSRS` import.)
struct ReviewState: Codable, Equatable {
    var due: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Double
    var scheduledDays: Double
    var reps: Int
    var lapses: Int
    /// Mirrors FSRS `CardState`: 0 = new, 1 = learning, 2 = review, 3 = relearning.
    var state: Int
    var lastReview: Date?

    init(due: Date = Date(), stability: Double = 0, difficulty: Double = 0,
         elapsedDays: Double = 0, scheduledDays: Double = 0, reps: Int = 0,
         lapses: Int = 0, state: Int = 0, lastReview: Date? = nil) {
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reps = reps
        self.lapses = lapses
        self.state = state
        self.lastReview = lastReview
    }
}

/// How well the user recalled a word in a review. Raw values match FSRS `Rating`
/// (`again = 1 … easy = 4`); FSRS's invalid `.manual = 0` is deliberately excluded,
/// so a `ReviewGrade` can never produce an out-of-range rating.
enum ReviewGrade: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}
