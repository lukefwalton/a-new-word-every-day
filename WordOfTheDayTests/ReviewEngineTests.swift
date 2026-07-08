import XCTest
@testable import WordOfTheDay

/// The hand-rolled FSRS-6 scheduler. Fuzz is disabled for determinism. Most
/// assertions only check ordering/direction — never exact day counts — so they
/// stay robust across parameter tweaks; the golden-vector block at the bottom
/// pins the ported math to reference values from py-fsrs.
final class ReviewEngineTests: XCTestCase {
    private let engine = ReviewEngine(enableFuzz: false)
    private let now = Fixtures.day(2026, 6, 28)

    func test_newWord_isDueImmediately() {
        XCTAssertTrue(engine.isDue(nil, now: now), "a never-reviewed word is due now")
    }

    func test_good_schedulesIntoTheFuture_andIsNoLongerDue() {
        let state = engine.grade(nil, .good, now: now)
        XCTAssertGreaterThan(state.due, now, "Good pushes the next review past now")
        XCTAssertFalse(engine.isDue(state, now: now))
    }

    func test_again_isScheduledSoonerThanGood() {
        let again = engine.grade(nil, .again, now: now)
        let good = engine.grade(nil, .good, now: now)
        XCTAssertLessThan(again.due, good.due, "a failed word comes back sooner than a known one")
    }

    func test_easy_isScheduledNoSoonerThanGood() {
        let good = engine.grade(nil, .good, now: now)
        let easy = engine.grade(nil, .easy, now: now)
        XCTAssertGreaterThanOrEqual(easy.due, good.due, "Easy never schedules sooner than Good")
    }

    func test_grade_recordsRepAndLeavesNewState() {
        let state = engine.grade(nil, .good, now: now)
        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.lastReview, now)
        XCTAssertNotEqual(state.state, 0, "a reviewed card is no longer in the New state")
    }

    func test_firstReviewAgain_isNotALapse() {
        // Failing a never-learned card keeps it in Review with no lapse recorded —
        // a lapse means forgetting something already learned (matches the FSRS ports).
        let state = engine.grade(nil, .again, now: now)
        XCTAssertEqual(state.lapses, 0)
        XCTAssertEqual(state.state, 2)
    }

    func test_subsequentAgain_countsAsLapse() {
        let first = engine.grade(nil, .good, now: now)
        let due = now.addingTimeInterval(first.scheduledDays * 86_400)
        let lapsed = engine.grade(first, .again, now: due)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertEqual(lapsed.state, 2)
    }

    func test_successfulReviewOnDueCard_growsStability() {
        let first = engine.grade(nil, .good, now: now)
        let due = now.addingTimeInterval(first.scheduledDays * 86_400)
        let second = engine.grade(first, .good, now: due)
        XCTAssertGreaterThan(second.stability, first.stability,
                             "recalling a card at its due date increases stability")
    }

    func test_reviewState_roundTripsThroughCodable() throws {
        let state = engine.grade(nil, .hard, now: now)
        let decoded = try JSONDecoder().decode(ReviewState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(state, decoded)
    }

    func test_preUpgradeFSRS5State_schedulesWithoutMigration() throws {
        // A card as the *previous* FSRS-5 engine would have persisted it (Good
        // init stability 3.1262, its init difficulty ≈ 5.31). Decoding it from
        // stored JSON and grading it under FSRS-6 must produce a sane schedule
        // with no migration step — the "ReviewState is engine-agnostic" claim.
        let reviewedAt = now.addingTimeInterval(-3 * 86_400)
        let legacy = ReviewState(due: now, stability: 3.1262, difficulty: 5.3146,
                                 elapsedDays: 3, scheduledDays: 3, reps: 1,
                                 lapses: 0, state: 2, lastReview: reviewedAt)
        let persisted = try JSONDecoder().decode(
            ReviewState.self, from: JSONEncoder().encode(legacy))

        let next = engine.grade(persisted, .good, now: now)
        XCTAssertGreaterThan(next.stability, legacy.stability,
                             "recalling a matured legacy card should grow stability")
        XCTAssertTrue(next.stability.isFinite)
        XCTAssertGreaterThanOrEqual(next.difficulty, 1)
        XCTAssertLessThanOrEqual(next.difficulty, 10)
        XCTAssertGreaterThan(next.due, now, "a passing grade schedules into the future")
        XCTAssertEqual(next.reps, 2)
    }

    // MARK: Golden vectors
    // Lock the FSRS-6 defaults so a transcription slip in the ported math (a wrong
    // weight, a wrong interval formula) fails a test rather than silently drifting
    // review cadence. Reference values were generated from py-fsrs v6.3.1 (the
    // source of the port) with fuzz off.

    func test_firstReviewStability_equalsDefaultWeights() {
        XCTAssertEqual(engine.grade(nil, .again, now: now).stability, 0.212, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .hard,  now: now).stability, 1.2931, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .good,  now: now).stability, 2.3065, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .easy,  now: now).stability, 8.2956, accuracy: 0.0001)
    }

    func test_firstReviewIntervals_followStability() {
        // At requestRetention 0.9 the interval modifier is exactly 1, so the
        // interval is round(stability), clamped to ≥ 1 day.
        XCTAssertEqual(engine.grade(nil, .again, now: now).scheduledDays, 1)
        XCTAssertEqual(engine.grade(nil, .hard,  now: now).scheduledDays, 1)
        XCTAssertEqual(engine.grade(nil, .good,  now: now).scheduledDays, 2)
        XCTAssertEqual(engine.grade(nil, .easy,  now: now).scheduledDays, 8)
    }

    func test_secondReviewAtDueDate_matchesReferenceOracle() {
        // A first-Good card (S 2.3065, due +2d) regraded exactly at its due date
        // exercises the forgetting curve (R ≈ 0.909493), the damped difficulty
        // update, and all four stability paths.
        let first = engine.grade(nil, .good, now: now)
        let due = now.addingTimeInterval(first.scheduledDays * 86_400)

        let again = engine.grade(first, .again, now: due)
        XCTAssertEqual(again.stability, 0.607580, accuracy: 0.0001)
        XCTAssertEqual(again.scheduledDays, 1)

        let hard = engine.grade(first, .hard, now: due)
        XCTAssertEqual(hard.stability, 7.513320, accuracy: 0.0001)
        XCTAssertEqual(hard.scheduledDays, 8)

        let good = engine.grade(first, .good, now: due)
        XCTAssertEqual(good.stability, 10.964332, accuracy: 0.0001)
        XCTAssertEqual(good.scheduledDays, 11)
        XCTAssertEqual(good.difficulty, 2.111214, accuracy: 0.0001)

        let easy = engine.grade(first, .easy, now: due)
        XCTAssertEqual(easy.stability, 18.521754, accuracy: 0.0001)
        XCTAssertEqual(easy.scheduledDays, 19)
    }

    func test_sameDayRegrade_usesShortTermFormula() {
        // Regrading within the same day (the in-session Again requeue) takes
        // FSRS-6's short-term path: Again shrinks stability, but a successful
        // grade never shrinks it (the increase factor clamps at 1).
        let first = engine.grade(nil, .good, now: now)
        let later = now.addingTimeInterval(600)

        let again = engine.grade(first, .again, now: later)
        XCTAssertEqual(again.stability, 0.775084, accuracy: 0.0001)
        XCTAssertEqual(again.scheduledDays, 1)

        let good = engine.grade(first, .good, now: later)
        XCTAssertEqual(good.stability, 2.3065, accuracy: 0.0001,
                       "a same-day Good must not shrink stability")
        XCTAssertEqual(good.scheduledDays, 2)
    }

    func test_firstReviewDifficulty_decreasesForEasierGrades() {
        let again = engine.grade(nil, .again, now: now).difficulty
        let good = engine.grade(nil, .good, now: now).difficulty
        let easy = engine.grade(nil, .easy, now: now).difficulty
        XCTAssertGreaterThan(again, good)
        XCTAssertGreaterThan(good, easy)
    }

    // MARK: Preview — the intervals shown under the study buttons

    func test_preview_coversEveryGrade() {
        let preview = engine.preview(nil, now: now)
        XCTAssertEqual(Set(preview.keys), Set(ReviewGrade.allCases))
    }

    func test_preview_matchesWhatGradeSchedules_whenFuzzOff() {
        // The badge under each button must equal what committing that grade actually
        // schedules — otherwise the preview lies. With fuzz off they're identical.
        let preview = engine.preview(nil, now: now)
        for grade in ReviewGrade.allCases {
            XCTAssertEqual(preview[grade], Int(engine.grade(nil, grade, now: now).scheduledDays),
                           "preview for \(grade) must match grade()'s scheduledDays")
        }
    }

    func test_preview_ordersAgainSoonestEasyLatest() {
        let preview = engine.preview(nil, now: now)
        XCTAssertLessThanOrEqual(preview[.again]!, preview[.good]!)
        XCTAssertLessThanOrEqual(preview[.good]!, preview[.easy]!)
    }

    func test_preview_reflectsTheCardsCurrentState() {
        // A card with review history previews from that history, not as a fresh card,
        // so a matured word shows longer intervals than a brand-new one.
        let matured = engine.grade(nil, .good, now: now)
        let due = now.addingTimeInterval(matured.scheduledDays * 86_400)
        XCTAssertGreaterThan(engine.preview(matured, now: due)[.good]!,
                             engine.preview(nil, now: now)[.good]!)
    }
}
