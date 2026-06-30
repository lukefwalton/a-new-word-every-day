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

    /// When the app bundle includes the OFL fonts (CI runs `fetch_fonts.sh`
    /// before building), every `LFWTypeface.family` must resolve in Core Text.
    /// Wrong names silently fall back to system fonts — this catches that drift.
    func test_bundledTypefaces_areRegisteredInAppBundle() {
        let bundled = Set(
            Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil)?
                .map { $0.lastPathComponent } ?? []
        )
        XCTAssertFalse(bundled.isEmpty, "No .ttf files in app bundle — run scripts/fetch_fonts.sh before testing")

        for face in LFWTypeface.allCases {
            XCTAssertTrue(
                bundled.contains(face.bundledFileName),
                "\(face.bundledFileName) missing from app bundle resources"
            )
            XCTAssertTrue(
                LFWVariableFont.isRegistered(face.family),
                "\(face.displayName): family '\(face.family)' not registered — check UIAppFonts and LFWTypeface.family"
            )
            let axes = LFWVariableFont.axes(of: face.family)
            XCTAssertFalse(
                axes.isEmpty,
                "\(face.displayName): no variation axes for '\(face.family)'"
            )
            XCTAssertNotNil(
                axes["wght"],
                "\(face.displayName): missing wght axis on '\(face.family)'"
            )
        }
    }
}
