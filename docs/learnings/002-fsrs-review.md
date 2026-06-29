# 002 — In-app review (FSRS)

The "someday Anki" seam from `SPEC.md` §10, built out. Discovery stays primary
(a word a day on the widget + Today); **study is a secondary, opt-in feature** in
the app. Star a word → it's in your deck → study it on a spaced-repetition schedule.

## Shape

| Piece | Where | Role |
|---|---|---|
| `ReviewState` | `Shared/ReviewState.swift` | Neutral, `Codable` per-word schedule (mirrors the FSRS card fields). |
| `ReviewGrade` | `Shared/ReviewState.swift` | Again/Hard/Good/Easy (raw 1–4 = FSRS rating). |
| `ReviewEngine` | `Features/Practice/ReviewEngine.swift` | The scheduler — a self-contained FSRS-5 port. The single algorithm boundary. |
| `ReviewQueue` | `Features/Practice/ReviewQueue.swift` | In-session queue; re-queues `.again` cards. Unit-tested. |
| `ReviewSessionView` | `Features/Practice/ReviewSessionView.swift` | The study loop: reveal, grade, reschedule. |
| `SharedStore.reviewStates` | `Shared/SharedStore.swift` | `[Word.id: ReviewState]`, JSON in the App Group. Dropped on unstar. |

`AppModel` exposes `dueWords()` / `dueCount` / `grade(_:_:)`; the Practice tab shows
a slim **"Study · N due"** entry only when something is due. The deck is exactly the
starred words; a starred word with no saved schedule is a new card, due now.

## Decisions

- **The FSRS algorithm is ported, not depended on.** `open-spaced-repetition/swift-fsrs`
  (MIT) declares its types `public` but its initializers/methods `internal`, so it
  can't be called from another module (its README example only compiles inside its own
  test target). Rather than vendor the whole package, `ReviewEngine.swift`
  re-implements the FSRS-5 math (long-term variant) directly, with attribution. That
  keeps the repo's **zero-runtime-dependency, Xcode-15 / Swift-5** posture, never
  touches the widget, and runs entirely on-device.
- **Persistence is engine-agnostic.** `ReviewState` is our own neutral type (not an
  FSRS package type), so the algorithm can be swapped again by editing only
  `ReviewEngine` — no data migration — and the widget (which links only `Shared/`)
  never sees the scheduler.
- **`ReviewEngine.grade` is total (non-throwing):** inputs are clamped and `ReviewGrade`
  excludes FSRS's invalid `.manual`, so there's no failure mode to surface.

## Session behaviour

The study queue is snapshotted once when `ReviewSessionView` appears, but a word
graded **Again** is re-appended (`ReviewQueue.advance`) so it returns later in the
same session ("study until caught up"). `dueCount` is recomputed on Practice-tab
appearance, on review-sheet dismiss, and on scene-active transitions, since due-ness
is time-based.

## Algorithm notes

FSRS-5 long-term scheduler, ported from swift-fsrs
`Sources/FSRS/Algorithm/FSRSAlgorithm.swift`: `DECAY = -0.5`, `FACTOR = 19/81`, the
19-weight default vector, forgetting curve `R = (1 + FACTOR·t/S)^DECAY`, initial
stability/difficulty per grade, difficulty mean-reversion toward the Easy initial
difficulty, recall-vs-forget stability, and
`interval = round(S · ((0.9^(1/DECAY) − 1)/FACTOR))` clamped to `[1, 36500]` with
optional fuzz. Tests assert ordering/direction only (fuzz off), never exact intervals.
