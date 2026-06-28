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

    /// Shared defaults suite. A nil suite means the App Group isn't provisioned
    /// for this target — falling back to `.standard` keeps the app alive, but the
    /// app and widget would each get their *own* `.standard` and silently stop
    /// sharing state. So make that misconfiguration loud rather than subtle.
    static var defaults: UserDefaults {
        if let suite = UserDefaults(suiteName: identifier) {
            return suite
        }
        #if DEBUG
        assertionFailure("App Group \(identifier) unavailable — app and widget will not share state. Check the entitlement and provisioning.")
        #endif
        NSLog("[WordOfTheDay] App Group %@ unavailable; using standard defaults. App and widget will NOT sync.", identifier)
        return .standard
    }
}
