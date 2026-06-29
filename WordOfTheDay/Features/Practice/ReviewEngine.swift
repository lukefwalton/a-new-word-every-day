import Foundation
import FSRS

/// The single boundary between the app and the FSRS package. Everything FSRS — the
/// `import`, the `Card` / `Rating` / `CardState` types, the scheduling call — is
/// contained in this one file, behind a small surface expressed in our own neutral
/// `ReviewState` / `ReviewGrade`. That keeps the dependency swappable (this is the
/// only file to rewrite if the engine ever changes) and out of the widget target,
/// which never links `FSRS`.
struct ReviewEngine {
    private let fsrs: FSRS

    /// `enableFuzz` defaults on — FSRS's recommended behaviour, which spreads due
    /// dates slightly so reviews don't all land on the same day. Tests pass `false`
    /// for deterministic intervals.
    init(enableFuzz: Bool = true) {
        fsrs = FSRS(parameters: FSRSParameters(enableFuzz: enableFuzz))
    }

    /// A brand-new, never-reviewed card, due immediately.
    func newState(now: Date = Date()) -> ReviewState {
        ReviewState(Card(due: now))
    }

    /// Advance a word's schedule for a grade. `nil` means the word has never been
    /// reviewed (a fresh card). This `throws` only if FSRS rejects the rating —
    /// impossible here, since `ReviewGrade` excludes the invalid `.manual` — so the
    /// throw is surfaced, never swallowed, and callers may treat it as a programmer
    /// error rather than a recoverable state.
    func grade(_ state: ReviewState?, _ grade: ReviewGrade, now: Date = Date()) throws -> ReviewState {
        let card = state?.card ?? Card(due: now)
        let result = try fsrs.next(card: card, now: now, grade: grade.rating)
        return ReviewState(result.card)
    }

    /// Whether a word is ready to study: never-reviewed cards (`nil`) are due now;
    /// otherwise it's due once `now` reaches the scheduled date.
    func isDue(_ state: ReviewState?, now: Date = Date()) -> Bool {
        guard let due = state?.due else { return true }
        return due <= now
    }
}

// MARK: - Neutral ⇄ FSRS conversion (the only place these types meet)

private extension ReviewState {
    /// Build a neutral state from an FSRS card.
    init(_ card: Card) {
        self.init(due: card.due,
                  stability: card.stability,
                  difficulty: card.difficulty,
                  elapsedDays: card.elapsedDays,
                  scheduledDays: card.scheduledDays,
                  reps: card.reps,
                  lapses: card.lapses,
                  state: card.state.rawValue,
                  lastReview: card.lastReview)
    }

    /// The equivalent FSRS card. An unrecognised `state` raw value — only possible
    /// from corrupt storage — falls back to `.new`.
    var card: Card {
        Card(due: due,
             stability: stability,
             difficulty: difficulty,
             elapsedDays: elapsedDays,
             scheduledDays: scheduledDays,
             reps: reps,
             lapses: lapses,
             state: CardState(rawValue: state) ?? .new,
             lastReview: lastReview)
    }
}

private extension ReviewGrade {
    /// Our grade as an FSRS rating. Raw values align, so this never falls back.
    var rating: Rating { Rating(rawValue: rawValue) ?? .good }
}
