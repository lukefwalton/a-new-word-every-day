import AppIntents

/// AppEnum needs static cases and a compile-time literal for
/// `caseDisplayRepresentations` (the AppIntents metadata extractor rejects
/// computed values), so the display names are spelled out here. Raw values
/// match `Language` codes, so `resolved` derives from the registry, and the
/// unit tests assert every registry language has a case — the display name is
/// the only thing to keep in sync by hand when adding a language.
enum WidgetLanguageOption: String, AppEnum {
    case appDefault
    case english = "en"
    case japanese = "ja"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Language")
    static var caseDisplayRepresentations: [WidgetLanguageOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .english: "English",
        .japanese: "Japanese · 日本語",
    ]

    var resolved: Language? { Language(rawValue: rawValue) }
}
