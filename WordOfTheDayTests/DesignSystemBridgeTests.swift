import XCTest
import SwiftUI
import LFWDesignSystem
@testable import WordOfTheDay

/// Exercises the design-system extensions through their public API as the app
/// uses them (the package's own suite covers internals separately).
final class DesignSystemBridgeTests: XCTestCase {

    func test_variableFontAxisTags() {
        XCTAssertEqual(LFWVariableFont.tag("wght"), 0x77676874)
        XCTAssertEqual(LFWVariableFont.weight, 0x77676874)
        XCTAssertEqual(LFWVariableFont.opticalSize, LFWVariableFont.tag("opsz"))
    }

    func test_themeConfigDefault() {
        XCTAssertEqual(LFWThemeConfig.default.typeface, .fraunces)
        XCTAssertEqual(LFWThemeConfig.default.palette, .deepSea)
    }

    func test_themeConfigCodableRoundTrip() throws {
        let theme = LFWThemeConfig(typeface: .literata, palette: .dusk, accentHueShift: -25)
        let decoded = try JSONDecoder().decode(LFWThemeConfig.self, from: JSONEncoder().encode(theme))
        XCTAssertEqual(theme, decoded)
    }

    func test_allPalettesResolveColors() {
        for palette in LFWPalette.allCases {
            let c = palette.colors
            XCTAssertNotNil(c.accent)
            XCTAssertNotNil(c.primaryText)
        }
    }

    func test_typographyResolvesAFont() {
        // Without the bundled font this returns a system fallback; the point is it
        // never traps and always yields a Font.
        for face in LFWTypeface.allCases {
            _ = LFWTypography.font(.heroWord, typeface: face)
            _ = LFWTypography.font(.definition, typeface: face, size: 18)
        }
    }

    func test_typefaceKindMapsToFallbackDesign() {
        XCTAssertEqual(LFWTypeface.fraunces.fallbackDesign, .serif)
        XCTAssertEqual(LFWTypeface.inter.fallbackDesign, .rounded)
    }
}
