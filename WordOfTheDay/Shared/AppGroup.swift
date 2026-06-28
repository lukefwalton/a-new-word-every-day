import Foundation

/// The App Group both the app and the widget share. Keep this identifier in sync
/// with the `com.apple.security.application-groups` entitlement in project.yml —
/// scripts/check_appgroup_sync.sh (and CI) fail the build if they drift, because
/// a mismatch would silently split the app and widget across two stores.
///
/// Everything stored here is small and on-device: stars, the difficulty band,
/// the theme choice. No account, no server, no analytics.
enum AppGroup {
    static let identifier = "group.com.lukewalton.wordoftheday"

    /// Shared defaults suite. Falls back to `.standard` only if the App Group
    /// isn't provisioned (e.g. a misconfigured fork), so the app still runs.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
