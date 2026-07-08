import XCTest
@testable import WordOfTheDay

/// Locks down the widget's language routing — `configuration.language.resolved
/// ?? store.primaryLanguage` — the one branch that lives outside the app model.
final class WidgetLanguageOptionTests: XCTestCase {

    func test_resolved_mapsEveryLanguageAndPassesThroughAppDefault() {
        XCTAssertNil(WidgetLanguageOption.appDefault.resolved)
        XCTAssertEqual(WidgetLanguageOption.english.resolved, .english)
        XCTAssertEqual(WidgetLanguageOption.japanese.resolved, .japanese)
        // Every registry language must be selectable for a widget.
        for language in Language.allCases {
            XCTAssertEqual(WidgetLanguageOption(rawValue: language.rawValue)?.resolved, language,
                           "\(language.displayName) missing from WidgetLanguageOption")
        }
    }

    /// The provider's exact resolution expression across the option × store matrix.
    func test_widgetLanguageResolution_matrix() {
        let cases: [(WidgetLanguageOption, [Language], Language)] = [
            (.appDefault, [.english], .english),
            (.appDefault, [.japanese], .japanese),
            (.appDefault, [.english, .japanese], .english),   // primary = first in registry order
            (.english,    [.japanese], .english),             // explicit choice beats enabled set
            (.japanese,   [.english], .japanese),
            (.japanese,   [.english, .japanese], .japanese),
        ]
        for (option, enabled, expected) in cases {
            let store = Fixtures.volatileStore()
            store.enabledLanguages = enabled
            XCTAssertEqual(option.resolved ?? store.primaryLanguage, expected,
                           "\(option) with \(enabled.map(\.rawValue)) should show \(expected.rawValue)")
        }
    }
}
