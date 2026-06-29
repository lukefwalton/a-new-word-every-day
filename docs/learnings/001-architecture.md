# 001 — Architecture

How the codebase is laid out and why, for anyone picking it up.

## Targets (XcodeGen → `project.yml`)

| Target | What |
|---|---|
| `WordOfTheDay` | The app. SwiftUI, iOS 17. |
| `WordWidgetExtension` | WidgetKit widget. Compiles the `Shared/` sources + the corpus directly; reads the App Group store. |
| `WordOfTheDayTests` | XCTest suite over the deterministic core. |
| `lfwdesignsystem` | Vendored design-system Swift Package (palette, onboarding kit, + the new font/theme modules). |

App and widget share **one App Group** (`group.com.lukewalton.wordoftheday`).
`scripts/check_appgroup_sync.sh` (run in CI) fails the build if the identifier in
`project.yml` ever drifts from `AppGroup.identifier` in Swift.

## The deterministic spine

The product rule "the widget shows the same word as the app" is solved by making
selection a **pure function**, not shared mutable state:

```
word(date) = seededShuffle(eligiblePool, salt)[ daysSinceInstall(date) % pool.count ]
```

- `SeededRandom` (SplitMix64) + `Array.seededShuffled(seed:)` — same seed ⇒ same
  order on every device/process.
- `DailySelector` sorts the eligible pool by id first, so the result is
  independent of how the corpus array was loaded.
- `eligiblePool` = words with `band <= user band`; the band comes from the
  onboarding swipes via `DifficultyModel`.

Because it's pure, the widget's `TimelineProvider` just calls the same code for
each day — no midnight write, no drift. This is the most-tested part of the app
(`DailySelectorTests`, `SeededRandomTests`).

## State

All mutable state is tiny and lives in `SharedStore` (App Group `UserDefaults`):
stars, band, theme, onboarding flag, per-install salt + date. `SharedStore` takes
an injected `UserDefaults`, so tests use a throwaway suite (`Fixtures.volatileStore`).
`AppModel` is the UI's `ObservableObject` layer; every mutation writes through to
the store and calls `WidgetReloader.reload()`.

## Design-system extensions

The shared package was system-fonts-only; this app needed configurable variable
fonts and theming, added as generic modules so the siblings could adopt them:

- `LFWVariableFont` — Core Text axis control (SwiftUI has no API for arbitrary
  axes), with a font cache for animation.
- `LFWTypography` — semantic `LFWTextRole`s → a chosen `LFWTypeface`, with a
  system fallback when the OFL font isn't bundled (so the app always renders).
- `LFWTheme` — `LFWThemeConfig` (typeface + `LFWPalette` + accent nudge), Codable
  so the widget reads the same choice.

## Licensing posture

App code is MIT; OFL fonts. The `words.json` corpus is **hand-authored and
public-domain (CC0)** — every headword, definition, and difficulty band written
for this app, no external data. `scripts/corpus_source.json` is the source;
`scripts/build_corpus.py` validates it and assigns each word a stable
hash-derived id (so persisted state keyed on `Word.id` survives corpus edits; no deps beyond
the stdlib). The full history of sources evaluated is in
`docs/prior-art-and-licensing.md`.
