import XCTest
@testable import WordOfTheDay

/// The spaced-repetition seam. Not wired into the UI yet, but tested so the
/// "someday practice" path is real and FSRS-swap-ready.
final class ReviewStateTests: XCTestCase {
    private let now = Fixtures.day(2026, 6, 28)

    func test_firstGoodReview_scheduledOneDayOut() {
        let s = SM2Scheduler.review(ReviewState(), grade: .good, now: now, calendar: Fixtures.utc)
        XCTAssertEqual(s.reps, 1)
        XCTAssertEqual(s.intervalDays, 1)
        XCTAssertEqual(s.due, Fixtures.day(2026, 6, 29))
    }

    func test_secondGoodReview_scheduledSixDaysOut() {
        var s = SM2Scheduler.review(ReviewState(), grade: .good, now: now, calendar: Fixtures.utc)
        s = SM2Scheduler.review(s, grade: .good, now: s.due!, calendar: Fixtures.utc)
        XCTAssertEqual(s.reps, 2)
        XCTAssertEqual(s.intervalDays, 6)
    }

    func test_intervalsGrow_afterThirdReview() {
        var s = ReviewState()
        for _ in 0..<4 {
            s = SM2Scheduler.review(s, grade: .good, now: s.due ?? now, calendar: Fixtures.utc)
        }
        XCTAssertGreaterThan(s.intervalDays, 6)
    }

    func test_again_lapsesAndResets() {
        var s = SM2Scheduler.review(ReviewState(), grade: .good, now: now, calendar: Fixtures.utc)
        s = SM2Scheduler.review(s, grade: .good, now: s.due!, calendar: Fixtures.utc)
        s = SM2Scheduler.review(s, grade: .again, now: s.due!, calendar: Fixtures.utc)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertEqual(s.reps, 0)
        XCTAssertEqual(s.intervalDays, 1)
    }

    func test_difficultyStaysInRange() {
        var s = ReviewState()
        for grade in [ReviewGrade.easy, .easy, .easy, .easy, .easy] {
            s = SM2Scheduler.review(s, grade: grade, now: s.due ?? now, calendar: Fixtures.utc)
        }
        XCTAssertGreaterThanOrEqual(s.difficulty, 1)
        XCTAssertLessThanOrEqual(s.difficulty, 10)
    }

    func test_reviewState_isCodable() throws {
        let s = SM2Scheduler.review(ReviewState(), grade: .hard, now: now, calendar: Fixtures.utc)
        let decoded = try JSONDecoder().decode(ReviewState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(s, decoded)
    }
}
