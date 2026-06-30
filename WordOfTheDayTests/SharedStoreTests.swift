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

    func test_reviewStates_defaultsToEmpty() {
        XCTAssertEqual(Fixtures.volatileStore().reviewStates, [:])
    }

    func test_reviewStates_roundTrip() {
        let store = Fixtures.volatileStore()
        let state = ReviewState(due: Fixtures.day(2026, 7, 1), stability: 3, difficulty: 5,
                                elapsedDays: 0, scheduledDays: 3, reps: 1, lapses: 0,
                                state: 2, lastReview: Fixtures.day(2026, 6, 28))
        store.reviewStates = [42: state]
        XCTAssertEqual(store.reviewStates, [42: state])
    }

    func test_toggleStar_clearsReviewStateOnUnstar() {
        let store = Fixtures.volatileStore()
        store.reviewStates = [10: ReviewState()]
        XCTAssertTrue(store.toggleStar(10))
        XCTAssertNotNil(store.reviewStates[10])
        XCTAssertFalse(store.toggleStar(10))
        XCTAssertNil(store.reviewStates[10])
    }

    func test_widgetPreferences_defaultsToBalanced() {
        XCTAssertEqual(Fixtures.volatileStore().widgetPreferences, .default)
    }

    func test_widgetPreferences_roundTrips() {
        let store = Fixtures.volatileStore()
        let prefs = WidgetPreferences(detailLevel: .rich, backgroundStyle: .accent, layoutStyle: .minimal)
        store.widgetPreferences = prefs
        XCTAssertEqual(store.widgetPreferences, prefs)
    }

    func test_widgetPreferences_tolerantDecode_defaultsMissingKeys() throws {
        // Preferences saved before the background/layout knobs existed carry only
        // detailLevel — they must decode (defaulting the new fields), not reset.
        let legacy = try JSONSerialization.data(withJSONObject: ["detailLevel": "rich"])
        let decoded = try JSONDecoder().decode(WidgetPreferences.self, from: legacy)
        XCTAssertEqual(decoded.detailLevel, .rich)
        XCTAssertEqual(decoded.backgroundStyle, .blobs)
        XCTAssertEqual(decoded.layoutStyle, .editorial)
    }

    func test_widgetPreferences_tolerantDecode_defaultsUnknownValues() throws {
        // A value written by a newer build (unknown case) must default, not throw.
        let future = try JSONSerialization.data(withJSONObject: [
            "detailLevel": "ultra",
            "backgroundStyle": "hologram",
            "layoutStyle": "carousel",
        ])
        let decoded = try JSONDecoder().decode(WidgetPreferences.self, from: future)
        XCTAssertEqual(decoded, .default)
    }

    func test_newPalettes_roundTripThroughTheme() {
        let store = Fixtures.volatileStore()
        for palette in [LFWPalette.forest, .dawn, .grape] {
            store.theme = LFWThemeConfig(typeface: .inter, palette: palette)
            XCTAssertEqual(store.theme.palette, palette)
        }
    }

    func test_theme_tolerantDecode_defaultsUnknownTypefaceAndPalette() throws {
        // A theme written with a palette/typeface this build doesn't know must default,
        // not throw (which would reset the whole theme).
        let future = try JSONSerialization.data(withJSONObject: [
            "typeface": "comic", "palette": "neon", "accentHueShift": 12.0,
        ])
        let decoded = try JSONDecoder().decode(LFWThemeConfig.self, from: future)
        XCTAssertEqual(decoded.typeface, .fraunces)
        XCTAssertEqual(decoded.palette, .deepSea)
        XCTAssertEqual(decoded.accentHueShift, 12.0)
    }

    func test_removeReviewStates_dropsOnlyGivenIds() {
        let store = Fixtures.volatileStore()
        store.reviewStates = [1: ReviewState(), 2: ReviewState(), 3: ReviewState()]
        store.removeReviewStates([2])
        XCTAssertEqual(Set(store.reviewStates.keys), [1, 3])
    }
}
