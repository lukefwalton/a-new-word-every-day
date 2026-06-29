import XCTest
@testable import WordOfTheDay

/// Locks in the one user-visible session rule: a card graded `.again` returns
/// later in the same session, while other grades retire it.
final class ReviewQueueTests: XCTestCase {
    private func word(_ id: Int) -> Word { Fixtures.word(id, band: 1) }

    func test_advancesInOrder_whenAllPassed() {
        var q = ReviewQueue([word(1), word(2)])
        XCTAssertEqual(q.current, word(1))
        XCTAssertEqual(q.position.total, 2)
        q.advance(grade: .good)
        XCTAssertEqual(q.current, word(2))
        q.advance(grade: .good)
        XCTAssertNil(q.current)
        XCTAssertTrue(q.isFinished)
    }

    func test_again_requeuesWithinSameSession() {
        var q = ReviewQueue([word(1), word(2)])
        q.advance(grade: .again)     // fail word 1 → re-queued to the end
        XCTAssertFalse(q.isFinished)
        XCTAssertEqual(q.current, word(2))
        q.advance(grade: .good)      // pass word 2
        XCTAssertEqual(q.current, word(1), "the failed card returns later in the same session")
        q.advance(grade: .good)      // finally pass word 1
        XCTAssertTrue(q.isFinished)
    }

    func test_emptyQueue_isFinished() {
        let q = ReviewQueue([])
        XCTAssertTrue(q.isFinished)
        XCTAssertNil(q.current)
    }
}
