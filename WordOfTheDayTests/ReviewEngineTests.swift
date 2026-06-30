import XCTest
@testable import WordOfTheDay

/// The hand-rolled FSRS-5 scheduler. Fuzz is disabled for determinism, but the
/// assertions still only check ordering/direction — never exact day counts — so
/// they stay robust across parameter tweaks.
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
        // a lapse means forgetting something already learned (matches swift-fsrs).
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

    // MARK: Golden vectors
    // Lock the FSRS-5 defaults so a transcription slip in the ported math (a wrong
    // weight, a wrong interval formula) fails a test rather than silently drifting
    // review cadence. These values follow directly from the default weights with
    // fuzz off; the multi-step recall/forget paths are covered by the ordering tests
    // above (no reference oracle is available here to generate exact later-step
    // outputs).

    func test_firstReviewStability_equalsDefaultWeights() {
        XCTAssertEqual(engine.grade(nil, .again, now: now).stability, 0.4072, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .hard,  now: now).stability, 1.1829, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .good,  now: now).stability, 3.1262, accuracy: 0.0001)
        XCTAssertEqual(engine.grade(nil, .easy,  now: now).stability, 15.4722, accuracy: 0.0001)
    }

    func test_firstReviewIntervals_followStability() {
        // interval = round(stability · ~1.0), clamped to ≥ 1 day.
        XCTAssertEqual(engine.grade(nil, .again, now: now).scheduledDays, 1)
        XCTAssertEqual(engine.grade(nil, .hard,  now: now).scheduledDays, 1)
        XCTAssertEqual(engine.grade(nil, .good,  now: now).scheduledDays, 3)
        XCTAssertEqual(engine.grade(nil, .easy,  now: now).scheduledDays, 15)
    }

    func test_firstReviewDifficulty_decreasesForEasierGrades() {
        let again = engine.grade(nil, .again, now: now).difficulty
        let good = engine.grade(nil, .good, now: now).difficulty
        let easy = engine.grade(nil, .easy, now: now).difficulty
        XCTAssertGreaterThan(again, good)
        XCTAssertGreaterThan(good, easy)
    }
}
