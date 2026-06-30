import XCTest
@testable import WordOfTheDay

/// The study buttons turn an FSRS interval (whole days) into a compact badge. These
/// lock the formatting so it stays faithful to the day count — a value never gets
/// coarsely rounded into a different schedule than the engine computed.
final class IntervalLabelTests: XCTestCase {

    func test_compact_showsExactDaysUnderAMonth() {
        XCTAssertEqual(IntervalLabel.compact(1), "1d")
        XCTAssertEqual(IntervalLabel.compact(3), "3d")
        XCTAssertEqual(IntervalLabel.compact(15), "15d")
        XCTAssertEqual(IntervalLabel.compact(29), "29d")
    }

    func test_compact_usesOneDecimalForMonths_notCoarseRounding() {
        // The regression the review flagged: 45 days must read "1.5mo", never "2mo".
        XCTAssertEqual(IntervalLabel.compact(45), "1.5mo")
        XCTAssertEqual(IntervalLabel.compact(75), "2.5mo")
    }

    func test_compact_dropsTrailingZeroDecimal() {
        XCTAssertEqual(IntervalLabel.compact(30), "1mo")
        XCTAssertEqual(IntervalLabel.compact(60), "2mo")
        XCTAssertEqual(IntervalLabel.compact(90), "3mo")
    }

    func test_compact_usesYearsPastAYear() {
        XCTAssertEqual(IntervalLabel.compact(365), "1y")
        XCTAssertEqual(IntervalLabel.compact(438), "1.2y")   // 1.2 × 365
        XCTAssertEqual(IntervalLabel.compact(730), "2y")
    }

    func test_spoken_isVoiceOverFriendlyAndPluralizes() {
        XCTAssertEqual(IntervalLabel.spoken(1), "in 1 day")
        XCTAssertEqual(IntervalLabel.spoken(3), "in 3 days")
        XCTAssertEqual(IntervalLabel.spoken(30), "in 1 month")
        XCTAssertEqual(IntervalLabel.spoken(45), "in 1.5 months")
        XCTAssertEqual(IntervalLabel.spoken(365), "in 1 year")
        XCTAssertEqual(IntervalLabel.spoken(730), "in 2 years")
    }
}
