import Foundation
import LFWDesignSystem

/// All mutable user state, persisted in the App Group so the app and widget read
/// one source of truth. It's tiny — a few arrays and a theme blob — so plain
/// `UserDefaults` beats a database here. Injectable for tests.
///
/// Nothing here ever leaves the device. No identifiers, no analytics, no network.
final class SharedStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The production store, backed by the App Group suite.
    static let shared = SharedStore(defaults: AppGroup.defaults)

    private enum Key {
        static let starred = "starredIDs"
        static let band = "difficultyBand"
        static let onboarding = "onboardingComplete"
        static let salt = "installSalt"
        static let installDate = "installDate"
        static let theme = "themeConfig"
        static let marks = "difficultyMarks"
        static let reviewStates = "reviewStates"
    }

    // MARK: Stars (the Practice list)

    var starredIDs: [Int] {
        get { (defaults.array(forKey: Key.starred) as? [Int]) ?? [] }
        set { defaults.set(newValue, forKey: Key.starred) }
    }

    func isStarred(_ id: Int) -> Bool { starredIDs.contains(id) }

    /// Toggle a star. Returns the new state. Newest stars sort first.
    @discardableResult
    func toggleStar(_ id: Int) -> Bool {
        var ids = starredIDs
        if let idx = ids.firstIndex(of: id) {
            ids.remove(at: idx)
            starredIDs = ids
            return false
        } else {
            starredIDs = [id] + ids
            return true
        }
    }

    // MARK: Difficulty

    var band: Int {
        get {
            guard defaults.object(forKey: Key.band) != nil else { return 2 }
            return defaults.integer(forKey: Key.band)
        }
        set { defaults.set(newValue, forKey: Key.band) }
    }

    /// In-app per-word marks (wordID → known). Feeds band nudges; local only.
    var difficultyMarks: [Int: Bool] {
        get {
            guard let raw = defaults.dictionary(forKey: Key.marks) as? [String: Bool] else { return [:] }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            defaults.set(raw, forKey: Key.marks)
        }
    }

    // MARK: Onboarding

    var onboardingComplete: Bool {
        get { defaults.bool(forKey: Key.onboarding) }
        set { defaults.set(newValue, forKey: Key.onboarding) }
    }

    // MARK: Install identity (for deterministic daily selection)

    /// Per-install seed for the daily permutation. Generated once on first read
    /// and persisted; stable thereafter. Randomness here only chooses *which*
    /// stable sequence — selection itself stays deterministic.
    var installSalt: UInt64 {
        if let existing = defaults.object(forKey: Key.salt) as? NSNumber {
            return existing.uint64Value
        }
        let salt = UInt64.random(in: UInt64.min...UInt64.max)
        defaults.set(NSNumber(value: salt), forKey: Key.salt)
        return salt
    }

    /// Install date (start of the day counter). Set once on first read.
    var installDate: Date {
        if let existing = defaults.object(forKey: Key.installDate) as? Date {
            return existing
        }
        let now = Date()
        defaults.set(now, forKey: Key.installDate)
        return now
    }

    // MARK: Theme

    var theme: LFWThemeConfig {
        get {
            guard let data = defaults.data(forKey: Key.theme),
                  let config = try? JSONDecoder().decode(LFWThemeConfig.self, from: data)
            else { return .default }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.theme)
            }
        }
    }

    // MARK: Review schedules (per-word FSRS state)

    /// Per-word review schedules, keyed by `Word.id`, JSON-encoded like `theme`
    /// (the values are structs, so the plist-friendly `dictionary` accessor that
    /// `difficultyMarks` uses won't serialize them). App-only in practice: the
    /// widget shares the container but never reads this key.
    var reviewStates: [Int: ReviewState] {
        get {
            guard let data = defaults.data(forKey: Key.reviewStates) else { return [:] }
            do {
                let raw = try JSONDecoder().decode([String: ReviewState].self, from: data)
                return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                    Int(key).map { ($0, value) }
                })
            } catch {
                // Don't silently wipe review progress on corruption — surface it so
                // it's diagnosable. We still degrade to empty so the app keeps working.
                NSLog("[WordOfTheDay] reviewStates failed to decode (%d bytes); treating as empty: %@",
                      data.count, String(describing: error))
                return [:]
            }
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            do {
                defaults.set(try JSONEncoder().encode(raw), forKey: Key.reviewStates)
            } catch {
                // A dropped write silently loses review progress otherwise — log it.
                NSLog("[WordOfTheDay] reviewStates failed to encode (%d entries): %@",
                      raw.count, String(describing: error))
            }
        }
    }

    /// Drop schedules for words that left the deck (unstarred), so stale FSRS state
    /// can't linger or silently resurrect if the word is starred again.
    func removeReviewStates(_ ids: [Int]) {
        guard !ids.isEmpty else { return }
        var states = reviewStates
        for id in ids { states.removeValue(forKey: id) }
        reviewStates = states
    }
}
