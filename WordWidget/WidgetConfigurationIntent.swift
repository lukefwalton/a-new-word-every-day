import AppIntents
import LFWDesignSystem

/// Per-widget customization, configured via long-press → **Edit Widget**. Every
/// option defaults to "App Default", which falls back to the choice set in the
/// app's Settings (read from the App Group) — so an unconfigured widget looks
/// exactly as it did before this existed. Each placed widget can override any of
/// these independently.
struct WordWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "A New Word Every Day"
    static var description = IntentDescription("Pick this widget's look, or keep your in-app defaults.")

    @Parameter(title: "Typeface", default: .appDefault)
    var typeface: WidgetTypefaceOption

    @Parameter(title: "Color Theme", default: .appDefault)
    var palette: WidgetPaletteOption

    @Parameter(title: "Background", default: .appDefault)
    var background: WidgetBackgroundOption

    @Parameter(title: "Layout", default: .appDefault)
    var layout: WidgetLayoutOption

    @Parameter(title: "Detail", default: .appDefault)
    var detail: WidgetDetailOption
}

// MARK: - Options
// Each option mirrors a design-system / WidgetPreferences value, plus an
// `appDefault` passthrough whose `resolved` is `nil` (→ use the Settings value).

enum WidgetTypefaceOption: String, AppEnum {
    case appDefault, fraunces, literata, inter, recursive

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Typeface")
    static var caseDisplayRepresentations: [WidgetTypefaceOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .fraunces: "Fraunces",
        .literata: "Literata",
        .inter: "Inter",
        .recursive: "Recursive",
    ]

    var resolved: LFWTypeface? {
        switch self {
        case .appDefault: return nil
        case .fraunces:   return .fraunces
        case .literata:   return .literata
        case .inter:      return .inter
        case .recursive:  return .recursive
        }
    }
}

enum WidgetPaletteOption: String, AppEnum {
    case appDefault, deepSea, paper, dusk, sepia, highContrast, forest, dawn, grape

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color Theme")
    static var caseDisplayRepresentations: [WidgetPaletteOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .deepSea: "Deep Sea",
        .paper: "Paper",
        .dusk: "Dusk",
        .sepia: "Sepia",
        .highContrast: "High Contrast",
        .forest: "Forest",
        .dawn: "Dawn",
        .grape: "Grape",
    ]

    var resolved: LFWPalette? {
        switch self {
        case .appDefault:   return nil
        case .deepSea:      return .deepSea
        case .paper:        return .paper
        case .dusk:         return .dusk
        case .sepia:        return .sepia
        case .highContrast: return .highContrast
        case .forest:       return .forest
        case .dawn:         return .dawn
        case .grape:        return .grape
        }
    }
}

enum WidgetBackgroundOption: String, AppEnum {
    case appDefault, aurora, clean, spotlight

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Background")
    static var caseDisplayRepresentations: [WidgetBackgroundOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .aurora: "Aurora",
        .clean: "Clean",
        .spotlight: "Spotlight",
    ]

    var resolved: WidgetBackgroundStyle? {
        switch self {
        case .appDefault: return nil
        case .aurora:     return .blobs
        case .clean:      return .gradient
        case .spotlight:  return .accent
        }
    }
}

enum WidgetLayoutOption: String, AppEnum {
    case appDefault, editorial, centered, minimal

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Layout")
    static var caseDisplayRepresentations: [WidgetLayoutOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .editorial: "Editorial",
        .centered: "Centered",
        .minimal: "Minimal",
    ]

    var resolved: WidgetLayoutStyle? {
        switch self {
        case .appDefault: return nil
        case .editorial:  return .editorial
        case .centered:   return .centered
        case .minimal:    return .minimal
        }
    }
}

enum WidgetDetailOption: String, AppEnum {
    case appDefault, compact, balanced, rich

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Detail")
    static var caseDisplayRepresentations: [WidgetDetailOption: DisplayRepresentation] = [
        .appDefault: "App Default",
        .compact: "Compact",
        .balanced: "Balanced",
        .rich: "Rich",
    ]

    var resolved: WidgetDetailLevel? {
        switch self {
        case .appDefault: return nil
        case .compact:    return .compact
        case .balanced:   return .balanced
        case .rich:       return .rich
        }
    }
}
