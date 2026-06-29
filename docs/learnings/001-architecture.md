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

App code is MIT; OFL fonts. The bundled 1000-word `words.json` is the deliberate
exception: its selection/bands come from wordfreq's share-alike data, so the word
list ships **CC BY-SA 4.0** (definitions from WordNet; examples from Gutenberg /
Brown / written for the app). The full matrix is in
`docs/prior-art-and-licensing.md`; attribution lives in `NOTICE` and the in-app
Acknowledgements.
