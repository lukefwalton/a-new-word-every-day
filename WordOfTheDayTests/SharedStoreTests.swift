import XCTest
import LFWDesignSystem
@testable import WordOfTheDay

final class SharedStoreTests: XCTestCase {

    func test_band_defaultsToTwo() {
        XCTAssertEqual(Fixtures.volatileStore().band, 2)
    }

    func test_band_persists() {
        let store = Fixtures.volatileStore()
        store.band = 4
        XCTAssertEqual(store.band, 4)
    }

    func test_toggleStar_addsNewestFirstAndRemoves() {
        let store = Fixtures.volatileStore()
        XCTAssertTrue(store.toggleStar(10))
        XCTAssertTrue(store.toggleStar(20))
        XCTAssertEqual(store.starredIDs, [20, 10], "newest star sorts first")
        XCTAssertTrue(store.isStarred(10))

        XCTAssertFalse(store.toggleStar(10))
        XCTAssertEqual(store.starredIDs, [20])
        XCTAssertFalse(store.isStarred(10))
    }

    func test_onboarding_persists() {
        let store = Fixtures.volatileStore()
        XCTAssertFalse(store.onboardingComplete)
        store.onboardingComplete = true
        XCTAssertTrue(store.onboardingComplete)
    }

    func test_installSalt_isStableAcrossReads() {
        let store = Fixtures.volatileStore()
        XCTAssertEqual(store.installSalt, store.installSalt)
    }

    func test_installDate_isStableAcrossReads() {
        let store = Fixtures.volatileStore()
        XCTAssertEqual(store.installDate, store.installDate)
    }

    func test_difficultyMarks_roundTrip() {
        let store = Fixtures.volatileStore()
        store.difficultyMarks = [1: true, 2: false, 3: true]
        XCTAssertEqual(store.difficultyMarks, [1: true, 2: false, 3: true])
    }

    func test_theme_defaultsToFamilyDefault() {
        XCTAssertEqual(Fixtures.volatileStore().theme, LFWThemeConfig.default)
    }

    func test_theme_roundTrips() {
        let store = Fixtures.volatileStore()
        let theme = LFWThemeConfig(typeface: .recursive, palette: .sepia, accentHueShift: 30)
        store.theme = theme
        XCTAssertEqual(store.theme, theme)
    }
}
