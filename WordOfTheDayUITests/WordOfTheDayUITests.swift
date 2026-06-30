import XCTest

/// End-to-end smoke tests for the onboarding gate and the three-tab shell.
/// Keeps the suite small and fast — the deterministic core is covered by unit tests.
final class WordOfTheDayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        // Stop the app between tests so the next test's launch isn't racing to
        // terminate a still-running instance — that race is what intermittently
        // surfaced as a "Failed to terminate …" launch failure on CI.
        app?.terminate()
        app = nil
    }

    func test_skipOnboarding_reachesTodayTab() throws {
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

    func test_calibrationDeck_swipeRight_advancesProgress() throws {
        app.launchArguments += ["-UITestResetOnboarding"]
        app.launch()

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.staticTexts["DO YOU KNOW THIS WORD?"].waitForExistence(timeout: 5))
        let progress = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ of [0-9]+$")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        XCTAssertTrue(progress.label.hasPrefix("0 of "))

        // Drag the top card right past the commit threshold (110pt).
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let offRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.42))
        center.press(forDuration: 0.15, thenDragTo: offRight)

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1 of ")).firstMatch
                .waitForExistence(timeout: 4)
        )
    }

    func test_starWord_appearsInPractice() throws {
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

    func test_studySession_revealAndGradeGood_finishes() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetOnboarding", "-UITestSkipOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Save to practice list"].waitForExistence(timeout: 5))
        app.buttons["Save to practice list"].tap()

        app.tabBars.buttons["Practice"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 3))

        let study = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Study'")).firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        study.tap()

        XCTAssertTrue(app.buttons["Reveal"].waitForExistence(timeout: 5))
        app.buttons["Reveal"].tap()
        let good = app.buttons["Good — grade your recall"]
        XCTAssertTrue(good.waitForExistence(timeout: 5))
        good.tap()

        XCTAssertTrue(app.staticTexts["All caught up"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 3))
    }

    func test_settings_aboutLinks_existAndOpenSupportSite() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetOnboarding", "-UITestSkipOnboarding"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let support = app.buttons["Support & feedback"]
        let privacy = app.buttons["Privacy policy"]
        scrollToElement(support, in: app)
        XCTAssertTrue(support.waitForExistence(timeout: 3))
        XCTAssertTrue(privacy.exists)

        support.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(
            safari.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "A New Word Every Day", "Privacy-first")
            ).firstMatch.waitForExistence(timeout: 15)
        )

        app.activate()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        if !app.tabBars.buttons["Settings"].isSelected {
            app.tabBars.buttons["Settings"].tap()
        }
        scrollToElement(privacy, in: app)
        privacy.tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(
            safari.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Privacy Policy")).firstMatch
                .waitForExistence(timeout: 10)
        )
    }

    /// Scroll a form until `element` is on screen (Settings About is below the fold).
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.isHittable {
            app.swipeUp()
        }
    }
}
