# 002 — In-app review (FSRS)

The "someday Anki" seam from `SPEC.md` §10, built out. Discovery stays primary
(a word a day on the widget + Today); **study is a secondary, opt-in feature** in
the app. Star a word → it's in your deck → study it on a spaced-repetition schedule.

## Shape

| Piece | Where | Role |
|---|---|---|
| `ReviewState` | `Shared/ReviewState.swift` | Neutral, `Codable` per-word schedule. **No `FSRS` import.** Mirrors the FSRS `Card` 1:1. |
| `ReviewGrade` | `Shared/ReviewState.swift` | Again/Hard/Good/Easy (raw 1–4 = FSRS `Rating`; the invalid `.manual` is excluded by construction). |
| `ReviewEngine` | `Features/Practice/ReviewEngine.swift` | **The only file that imports `FSRS`.** Converts `ReviewState ⇄ Card`, drives `next()`. |
| `ReviewSessionView` | `Features/Practice/ReviewSessionView.swift` | The study loop: tap to reveal, grade, FSRS reschedules. |
| `SharedStore.reviewStates` | `Shared/SharedStore.swift` | `[Word.id: ReviewState]`, JSON in the App Group. Dropped when a word is unstarred. |

`AppModel` exposes `dueWords()` / `dueCount` / `grade(_:_:)`; the Practice tab shows
a slim **"Study · N due"** entry only when something is due. The deck is exactly the
starred words; a starred word with no saved schedule is a new card, due now.

## Decisions

- **Engine: `open-spaced-repetition/swift-fsrs` (MIT), the app's first runtime
  dependency.** "Anki" means FSRS, and a maintained native-Swift FSRS beats
  hand-rolling one. It's resolved at *build* time only — no runtime network, so the
  local-first/no-tracking doctrine holds; review data never leaves the device.
- **Pinned with `exactVersion: 5.0.0` in `project.yml`, not a committed
  `Package.resolved`.** The Xcode project is generated and `*.xcodeproj` is
  gitignored, so the lockfile lives *inside* an ignored directory. The exact pin in
  `project.yml` is the lock instead, and it's deterministic. (v5.0.0 is the latest
  tag = FSRS-5; FSRS-6 is only on untagged `main`.) Its `Package.swift` declares
  `swift-tools-version: 6.0`, so CI runs on `macos-15` (Xcode 16) to resolve it —
  the app still compiles in Swift 5 language mode for iOS 17.

## Session behaviour

The study queue is snapshotted once when `ReviewSessionView` appears, but a word
graded **Again** is re-appended to that queue so it returns later in the same
session ("study until caught up"). `dueCount` is recomputed on Practice-tab
appearance as well as on grade/star changes, since due-ness is time-based.
- **Persistence is engine-agnostic.** `ReviewState` is our own type, not FSRS's
  `Card`, so swapping schedulers later is a one-file change in `ReviewEngine`, not a
  data migration — and the package import never reaches the **widget**, which links
  only `Shared/` and shows no review state.
- **Throws are surfaced, not hidden.** `ReviewEngine.grade` is `throws`; `AppModel`
  catches with `assertionFailure` + log and leaves the schedule untouched. It can't
  actually fail (no `.manual`), but it isn't swallowed.

## Tests

`ReviewEngineTests` builds the engine with `enableFuzz: false` and asserts only
ordering/direction (again < good ≤ easy; new is due; Good schedules out), never exact
day counts — robust across FSRS parameter changes. `SharedStoreTests` round-trips
`reviewStates`; `AppModelTests` covers star→due, grade→cleared, unstar→schedule dropped.

The old SM-2 placeholder (`SM2Scheduler` + the previous `ReviewState`) and its tests
were deleted — `ReviewEngine` is the reversible boundary now, so a second scheduler
would just be stale code.
