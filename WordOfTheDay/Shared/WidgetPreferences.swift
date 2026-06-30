import Foundation

/// How much definition text the Home Screen widget shows. Typeface, palette, and
/// accent hue come from `LFWThemeConfig` — this only controls information density.
public enum WidgetDetailLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case balanced
    case rich

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact:  return "Compact"
        case .balanced: return "Balanced"
        case .rich:     return "Rich"
        }
    }

    public var subtitle: String {
        switch self {
        case .compact:  return "Word + part of speech"
        case .balanced: return "One definition line on small"
        case .rich:     return "More definition on every size"
        }
    }

    func definitionLines(family: WidgetLayoutSize) -> Int {
        switch (self, family) {
        case (_, .small):           return self == .rich ? 2 : (self == .balanced ? 1 : 0)
        case (.compact, .medium):   return 1
        case (.balanced, .medium):  return 2
        case (.rich, .medium):      return 3
        case (.compact, .large):    return 2
        case (.balanced, .large):   return 4
        case (.rich, .large):       return 6
        case (_, .extraLarge):      return 8
        }
    }

    var showsDefinitionOnSmall: Bool { definitionLines(family: .small) > 0 }
}

/// Layout bucket for widget presentation helpers (mirrors WidgetKit families).
public enum WidgetLayoutSize: Sendable {
    case small, medium, large, extraLarge
}

/// Widget-only display prefs, persisted in the App Group beside theme.
public struct WidgetPreferences: Codable, Equatable, Sendable {
    public var detailLevel: WidgetDetailLevel

    public init(detailLevel: WidgetDetailLevel = .balanced) {
        self.detailLevel = detailLevel
    }

    public static let `default` = WidgetPreferences()
}
