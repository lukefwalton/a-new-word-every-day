import XCTest
@testable import WordOfTheDay

/// The FSRS scheduling boundary. Fuzz is disabled so runs are deterministic, but
/// the assertions still only check ordering / direction — never exact day counts —
/// so they stay robust across FSRS parameter or version changes.
final class ReviewEngineTests: XCTestCase {
    private let engine = ReviewEngine(enableFuzz: false)
    private let now = Fixtures.day(2026, 6, 28)

    func test_newWord_isDueImmediately() {
        XCTAssertTrue(engine.isDue(nil, now: now), "a never-reviewed word is due now")
    }

    func test_good_schedulesIntoTheFuture_andIsNoLongerDue() throws {
        let state = try engine.grade(nil, .good, now: now)
        XCTAssertGreaterThan(state.due, now, "Good pushes the next review past now")
        XCTAssertFalse(engine.isDue(state, now: now))
    }

    func test_again_isScheduledSoonerThanGood() throws {
        let again = try engine.grade(nil, .again, now: now)
        let good = try engine.grade(nil, .good, now: now)
        XCTAssertLessThan(again.due, good.due, "a failed word comes back sooner than a known one")
    }

    func test_easy_isScheduledNoSoonerThanGood() throws {
        let good = try engine.grade(nil, .good, now: now)
        let easy = try engine.grade(nil, .easy, now: now)
        XCTAssertGreaterThanOrEqual(easy.due, good.due, "Easy never schedules sooner than Good")
    }

    func test_grade_recordsRepAndLeavesNewState() throws {
        let state = try engine.grade(nil, .good, now: now)
        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.lastReview, now)
        XCTAssertNotEqual(state.state, 0, "a reviewed card is no longer in the New state")
    }

    func test_reviewState_roundTripsThroughCodable() throws {
        let state = try engine.grade(nil, .hard, now: now)
        let decoded = try JSONDecoder().decode(ReviewState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(state, decoded)
    }
}
