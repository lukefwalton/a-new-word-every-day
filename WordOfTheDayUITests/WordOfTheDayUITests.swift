import XCTest

/// End-to-end smoke tests for the onboarding gate and the three-tab shell.
/// Keeps the suite small and fast — the deterministic core is covered by unit tests.
final class WordOfTheDayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_skipOnboarding_reachesTodayTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetOnboarding"]
        app.launch()

        // Walk the three intro pages (Next → Next → Start).
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // Skip straight to the app at the default band.
        let skip = app.buttons["Skip — start in the middle"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        // Today tab should show the daily word chrome.
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(todayTab.isSelected)
        XCTAssertTrue(app.staticTexts["WORD OF THE DAY"].waitForExistence(timeout: 5))
    }

    func test_starWord_appearsInPractice() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetOnboarding", "-UITestSkipOnboarding"]
        app.launch()

        let star = app.buttons["Save to practice list"]
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        star.tap()
        XCTAssertTrue(app.buttons["Remove from practice list"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Practice"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 3))
        // At least one starred row should exist (exact word varies by install salt).
        XCTAssertGreaterThan(app.cells.count, 0)
    }
}
