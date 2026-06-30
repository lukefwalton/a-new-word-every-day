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

/// Backdrop treatment for the Home Screen widget.
public enum WidgetBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case blobs       // gradient + drifting color blobs (the lush default)
    case gradient    // a clean two-tone gradient, no blobs
    case accent      // bold, accent-forward backdrop with a soft glow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blobs:    return "Aurora"
        case .gradient: return "Clean"
        case .accent:   return "Spotlight"
        }
    }

    public var subtitle: String {
        switch self {
        case .blobs:    return "Drifting color blobs"
        case .gradient: return "Smooth two-tone"
        case .accent:   return "Bold accent glow"
        }
    }
}

/// Composition of the Home Screen widget's content.
public enum WidgetLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case editorial   // left-aligned, eyebrow + surface card (the default)
    case centered    // centered word and text on the card
    case minimal     // type-forward: no eyebrow or card chrome

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .editorial: return "Editorial"
        case .centered:  return "Centered"
        case .minimal:   return "Minimal"
        }
    }

    public var subtitle: String {
        switch self {
        case .editorial: return "Left-aligned, framed"
        case .centered:  return "Centered on the card"
        case .minimal:   return "Just the word, no chrome"
        }
    }

    public var isCentered: Bool { self == .centered }
    public var showsEyebrow: Bool { self != .minimal }
    public var showsCard: Bool { self != .minimal }
}

/// Widget-only display prefs, persisted in the App Group beside theme.
public struct WidgetPreferences: Codable, Equatable, Sendable {
    public var detailLevel: WidgetDetailLevel
    public var backgroundStyle: WidgetBackgroundStyle
    public var layoutStyle: WidgetLayoutStyle

    public init(detailLevel: WidgetDetailLevel = .balanced,
                backgroundStyle: WidgetBackgroundStyle = .blobs,
                layoutStyle: WidgetLayoutStyle = .editorial) {
        self.detailLevel = detailLevel
        self.backgroundStyle = backgroundStyle
        self.layoutStyle = layoutStyle
    }

    public static let `default` = WidgetPreferences()

    private enum CodingKeys: String, CodingKey {
        case detailLevel, backgroundStyle, layoutStyle
    }

    // Tolerant decode: default a field that is either MISSING (saved before the knob
    // existed) or an UNKNOWN raw value (saved by a newer build, opened by an older
    // one), rather than failing the whole decode and resetting every preference. We
    // read each as a raw string and map it ourselves so an unrecognized case falls
    // back instead of throwing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawDetail = (try? c.decodeIfPresent(String.self, forKey: .detailLevel)) ?? nil
        let rawBackground = (try? c.decodeIfPresent(String.self, forKey: .backgroundStyle)) ?? nil
        let rawLayout = (try? c.decodeIfPresent(String.self, forKey: .layoutStyle)) ?? nil
        detailLevel = rawDetail.flatMap(WidgetDetailLevel.init(rawValue:)) ?? .balanced
        backgroundStyle = rawBackground.flatMap(WidgetBackgroundStyle.init(rawValue:)) ?? .blobs
        layoutStyle = rawLayout.flatMap(WidgetLayoutStyle.init(rawValue:)) ?? .editorial
    }
}
