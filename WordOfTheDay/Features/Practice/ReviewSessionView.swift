import SwiftUI
import LFWDesignSystem

/// A lightweight, opt-in study session over the words due now — the "Anki behind
/// the widget", kept deliberately small: one card at a time, tap to reveal the
/// definition, grade Again/Hard/Good/Easy, and FSRS schedules the next review. No
/// decks, no editing. Reached from the Practice tab; the daily word + widget stay
/// the primary surface.
struct ReviewSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Snapshotted once on appear so grading a word (which reschedules it out of
    /// "due") doesn't reshuffle the deck mid-session. `ReviewQueue` re-queues a
    /// failed card so it returns later in this same session.
    @State private var queue = ReviewQueue([])
    @State private var revealed = false
    /// Bumped on each commit so `.sensoryFeedback` fires a tap per grade. `lastGrade`
    /// lets the haptic differ for a miss (Again) vs a recall.
    @State private var gradeTick = 0
    @State private var lastGrade: ReviewGrade?
    /// The instant the current card was revealed. Both the interval preview and the
    /// grade commit read it, so the previewed base interval is exactly the base the
    /// commit schedules against (only fuzz then jitters the final due date).
    @State private var reviewNow = Date()

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: model.theme)
            VStack(spacing: 0) {
                header
                if let word = queue.current {
                    card(word)
                } else {
                    finished
                }
            }
            .padding(24)
        }
        .onAppear { if queue.words.isEmpty { queue = ReviewQueue(model.dueWords()) } }
        // Subtle, opt-in haptics: a soft tap on reveal, and a per-grade tap on commit
        // (a touch firmer for a missed card) so grading feels physical without noise.
        .sensoryFeedback(trigger: revealed) { _, isRevealed in isRevealed ? .selection : nil }
        .sensoryFeedback(trigger: gradeTick) { _, _ in
            lastGrade == .again ? .impact(weight: .medium) : .impact(weight: .light)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            .accessibilityLabel("Close study session")
            Spacer()
            if queue.current != nil {
                Text("\(queue.position.current) of \(queue.position.total)")
                    .font(LFWTypography.font(.eyebrow, typeface: typeface))
                    .kerning(1.5)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            // Invisible twin of the close button so the counter stays centred.
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func card(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("WORD")
                .font(LFWTypography.font(.eyebrow, typeface: typeface))
                .kerning(2)
                .foregroundStyle(palette.accent)

            // `.id(word.id)` rebuilds the hero per card so its reveal animation replays.
            HeroWordView(word: word.word, typeface: typeface, color: palette.primaryText, size: 56)
                .id(word.id)

            if revealed {
                Text(word.partOfSpeechLabel)
                    .font(LFWTypography.font(.partOfSpeech, typeface: typeface))
                    .foregroundStyle(palette.accent)
                Text(word.definition)
                    .font(LFWTypography.font(.definition, typeface: typeface))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap to reveal the definition")
                    .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            if revealed {
                gradeButtons(word)
            } else {
                Button { reveal() } label: {
                    Text("Reveal").frame(maxWidth: .infinity)
                }
                .buttonStyle(.themedCTA(palette: palette, filled: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { if !revealed { reveal() } }
        .animation(.easeInOut(duration: 0.2), value: revealed)
    }

    private func gradeButtons(_ word: Word) -> some View {
        // The base FSRS interval each grade schedules, shown under its button so the
        // word's return is visible before committing. Anchored to `reviewNow` — the
        // same instant the commit uses — so the badge is the exact base interval the
        // grade lands on (the final due date is then jittered a few percent by fuzz).
        let intervals = model.reviewPreview(word, now: reviewNow)
        return HStack(alignment: .top, spacing: 10) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                VStack(spacing: 6) {
                    Button { commit(grade, for: word) } label: {
                        Text(grade.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.themedCTA(palette: palette, filled: grade == .good))
                    .accessibilityLabel("\(grade.label) — grade your recall")

                    if let days = intervals[grade] {
                        Text(IntervalLabel.compact(days))
                            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 12))
                            .monospacedDigit()
                            .foregroundStyle(palette.secondaryText)
                            .accessibilityLabel("returns \(IntervalLabel.spoken(days))")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.accent)
            Text("All caught up")
                .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 24))
                .foregroundStyle(palette.primaryText)
            Text("You've reviewed every word that was due.")
                .font(LFWTypography.font(.uiBody, typeface: typeface, size: 15))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button { dismiss() } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.themedCTA(palette: palette, filled: true))
        }
        .frame(maxWidth: .infinity)
    }

    private func reveal() {
        reviewNow = Date()      // anchor preview + commit to one instant
        revealed = true
    }

    private func commit(_ grade: ReviewGrade, for word: Word) {
        lastGrade = grade
        gradeTick += 1
        model.grade(word, grade, now: reviewNow)
        queue.advance(grade: grade)
        revealed = false
    }
}

private extension ReviewGrade {
    var label: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
}

/// Formats an FSRS interval (whole days) for the study buttons. Kept faithful to the
/// scheduled day count — exact days under a month, then months/years to one decimal —
/// so a value like 45 days reads "1.5mo", never a coarse "2mo". File-scope (not
/// view-private) so it can be unit-tested directly.
enum IntervalLabel {
    /// Compact badge, e.g. "3d", "1.5mo", "2y".
    static func compact(_ days: Int) -> String {
        let (value, unit) = parts(days)
        return value + unit.short
    }

    /// VoiceOver phrase, e.g. "in 3 days", "in 1.5 months".
    static func spoken(_ days: Int) -> String {
        let (value, unit) = parts(days)
        return "in \(value) \(unit.word)\(value == "1" ? "" : "s")"
    }

    private enum Unit {
        case day, month, year
        var short: String {
            switch self {
            case .day:   return "d"
            case .month: return "mo"
            case .year:  return "y"
            }
        }
        var word: String {
            switch self {
            case .day:   return "day"
            case .month: return "month"
            case .year:  return "year"
            }
        }
    }

    private static func parts(_ days: Int) -> (String, Unit) {
        switch days {
        case ..<30:  return ("\(days)", .day)
        case ..<365: return (decimal(Double(days) / 30), .month)
        default:     return (decimal(Double(days) / 365), .year)
        }
    }

    /// One decimal place, dropping a trailing ".0" so 2.0 → "2" but 1.5 stays "1.5".
    private static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))"
            : String(format: "%.1f", rounded)
    }
}
