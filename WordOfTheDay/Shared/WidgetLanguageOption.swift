import AppIntents

/// AppEnum needs static cases, so languages are enumerated here — but raw
/// values, display names, and resolution all derive from the `Language`
/// registry, so a new language only needs its case added (names can't drift).
enum WidgetLanguageOption: String, AppEnum {
    case appDefault
    case english = "en"
    case japanese = "ja"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Language")
    static var caseDisplayRepresentations: [WidgetLanguageOption: DisplayRepresentation] = {
        var reps: [WidgetLanguageOption: DisplayRepresentation] = [.appDefault: "App Default"]
        for language in Language.allCases {
            guard let option = WidgetLanguageOption(rawValue: language.rawValue) else { continue }
            reps[option] = DisplayRepresentation(
                stringLiteral: language.nativeName == language.displayName
                    ? language.displayName
                    : "\(language.displayName) · \(language.nativeName)")
        }
        return reps
    }()

    var resolved: Language? { Language(rawValue: rawValue) }
}
