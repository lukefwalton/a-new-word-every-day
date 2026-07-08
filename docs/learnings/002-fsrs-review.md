# 002 — In-app review (FSRS)

The "someday Anki" seam from `SPEC.md` §10, built out. Discovery stays primary
(a word a day on the widget + Today); **study is a secondary, opt-in feature** in
the app. Star a word → it's in your deck → study it on a spaced-repetition schedule.

## Shape

| Piece | Where | Role |
|---|---|---|
| `ReviewState` | `Shared/ReviewState.swift` | Neutral, `Codable` per-word schedule (mirrors the FSRS card fields). |
| `ReviewGrade` | `Shared/ReviewState.swift` | Again/Hard/Good/Easy (raw 1–4 = FSRS rating). |
| `ReviewEngine` | `Features/Practice/ReviewEngine.swift` | The scheduler — a self-contained FSRS-6 port. The single algorithm boundary. |
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
  test target). Rather than vendor a package, `ReviewEngine.swift` re-implements the
  FSRS math directly, with attribution — originally the FSRS-5 long-term variant from
  swift-fsrs, now the FSRS-6 algorithm from `open-spaced-repetition/py-fsrs` v6.3.1
  (MIT), which doubles as the golden-vector oracle in `ReviewEngineTests`. That keeps
  the repo's **zero-runtime-dependency, Xcode-15 / Swift-5** posture, never touches
  the widget, and runs entirely on-device. The swap from FSRS-5 to FSRS-6 touched
  only this file plus test vectors — exactly the seam working as designed.
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

FSRS-6, ported from py-fsrs v6.3.1 `fsrs/scheduler.py`: the 21-parameter default
vector; parametric decay `DECAY = −w[20]` with `FACTOR = 0.9^(1/DECAY) − 1`;
forgetting curve `R = (1 + FACTOR·t/S)^DECAY`; initial stability/difficulty per
grade; difficulty updates with linear damping (`ΔD·(10−D)/9`) then mean reversion
toward the raw (unclamped) Easy initial difficulty; recall-vs-forget stability with
FSRS-6's post-lapse ceiling `S/e^(w17·w18)`; a same-day short-term path
(`S · e^(w17·(g−3+w18)) · S^(−w19)`, never shrinking on success) used when the
previous review was < 1 day ago — which is what the in-session Again requeue hits;
and `interval = round(S · ((0.9^(1/DECAY) − 1)/FACTOR))` clamped to `[1, 36500]`
with optional fuzz (at retention 0.9 the modifier is exactly 1, so interval =
round(S)). Behavioral tests assert ordering/direction (fuzz off); golden-vector
tests pin first/second-review and same-day values against py-fsrs. Persisted
FSRS-5 states need no migration — stability/difficulty carry over as valid inputs.
