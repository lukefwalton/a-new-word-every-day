import Foundation

/// The in-session study queue. Extracted from `ReviewSessionView` so the one
/// user-visible policy — a card you fail (`.again`) returns later in the *same*
/// session ("study until caught up") — is a plain value type we can unit-test,
/// keeping the view thin.
struct ReviewQueue {
    private(set) var words: [Word]
    private(set) var index = 0

    init(_ words: [Word]) { self.words = words }

    /// The card being studied now, or `nil` once the session is done.
    var current: Word? { index < words.count ? words[index] : nil }

    var isFinished: Bool { index >= words.count }

    /// 1-based position for display, e.g. `(2, 5)` → "2 of 5".
    var position: (current: Int, total: Int) {
        (min(index + 1, words.count), words.count)
    }

    /// Advance past the current card after grading. A failed card (`.again`) is
    /// re-appended so it comes back later this session; any other grade retires it.
    mutating func advance(grade: ReviewGrade) {
        if grade == .again, let word = current { words.append(word) }
        index += 1
    }
}
