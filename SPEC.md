# Word of the Day — Spec

A beautiful, local-first iOS app + Home Screen widget that teaches an elevated
English word each day. The widget is the product; the app is the place you
configure it, practice starred words, and (on first run) calibrate your level
with a Tinder-style swipe deck.

This is a planning document. No app code exists yet — see [Status](#status--scope).

---

## 1. Product at a glance

- **One word a day**, shown beautifully in a configurable **variable font** and
  color theme, primarily on the **Home Screen / Lock Screen widget**.
- **Star** a word to drop it into a **Practice** list. (Anki export is a
  someday; the seam is designed in now — see §10.)
- **Swipe onboarding** (Tinder-style, two-way: *Know* / *Don't know*) calibrates
  your difficulty band so day-one words land at the right level. Difficulty
  grounding is **100% on-device** — no accounts, no servers, no tracking.
- **Configurable**: typeface (curated OFL variable fonts) + color theme.

### Confirmed product decisions
| Decision | Choice |
|---|---|
| Default hero typeface | **Fraunces** (OFL variable display serif) |
| Onboarding swipe model | **2-way**: Know / Don't know |
| Default palette | **Deep Sea** (the existing `LFWColors` family dark gradient) |
| First deliverable | **This spec** (lock the plan, then scaffold) |

---

## 2. Doctrine (inherited from the app family)

`workout-logger` and `stop-political-texts` establish conventions this app
follows so it feels like a sibling:

- **Local-first, no servers, no tracking.** Everything — corpus, stars,
  difficulty marks — lives on device. CI in the sibling repos literally has a
  "privacy doctrine" guard. We keep that posture: the app makes **zero network
  calls** at runtime. (Corpus is built offline and bundled; see §9.)
- **Shared design system** (`lfwdesignsystem`, a vendored Swift Package) owns
  the family look. We **extend** it here (variable fonts + theming are net-new)
  rather than fork the language.
- **XcodeGen** `project.yml`, `scripts/generate.sh` with a local team-id merge,
  CI "guardrail" scripts, and `docs/learnings/`.
- **App Group + read-only widget** data pattern, exactly like `WorkoutWidget`.

---

## 3. Architecture

### 3.1 Targets & identifiers
Mirrors `workout-logger`'s XcodeGen layout.

| Target | Type | Bundle ID |
|---|---|---|
| `WordOfTheDay` | application | `com.lukewalton.wordoftheday` |
| `WordWidgetExtension` | app-extension (WidgetKit) | `com.lukewalton.wordoftheday.widget` |
| `WordOfTheDayTests` | unit-test | `com.lukewalton.wordoftheday.tests` |

- **App Group:** `group.com.lukewalton.wordoftheday` (guarded by a
  `scripts/check_appgroup_sync.sh`, same as the workout repo).
- **Deployment target:** iOS 17 (matches `workout-logger`; needed for the
  interactive-widget `AppIntent` star button in §8).
- **Device family:** iPhone (1). Swift 5.0, `projectFormat: xcode15_0`.

### 3.2 Data: what's bundled vs. mutable
The corpus is **read-only and identical** for everyone, so we bundle it; only
small user state is mutable.

- **Corpus** → `words.json` (or a prebuilt read-only SQLite) **compiled into
  both the app and widget targets** as a resource. ~1,500–3,000 words. Built
  offline by a script (§9), never fetched.
- **User state** → App Group `UserDefaults(suiteName:)`, because it's tiny and
  the widget needs to read it:
  - `starredIDs: [Int]` — the Practice list
  - `difficultyMarks: [Int: Mark]` — per-word Know/Don't-know (from onboarding
    + any in-app marking)
  - `band: Int` — the user's current difficulty band (derived from marks)
  - `theme: ThemeConfig` — typeface + palette (Codable, JSON-encoded)
  - `onboardingComplete: Bool`
  - `installSalt: Int` — a per-install seed for the daily permutation

> Why not a shared SQLite for state like the workout app? Vocab user-state is
> a few arrays of ints; `UserDefaults` in the App Group is simpler and the
> widget reads it with no SQLite link. The **corpus** can still be SQLite if we
> want indexed lookups, but bundled (read-only), not in the App Group.

The app calls `WidgetCenter.shared.reloadAllTimelines()` after any star or
theme change, exactly like `WidgetRefresher` in `workout-logger`.

### 3.3 Daily word selection (deterministic, widget-safe)
The widget must show the **same** word the app shows **without** a shared write.
So selection is a pure function of `(date, installSalt, band, corpus)`:

```
eligiblePool = corpus.filter { $0.band <= userBand }      // at or below your level
order        = seededPermutation(eligiblePool, seed: installSalt)
dayIndex     = daysSsince(installDate)                      // integer day counter
todaysWord   = order[dayIndex % order.count]
```

- `seededPermutation` is a stable Fisher–Yates keyed on `installSalt` (a small
  SplitMix64-style PRNG, **not** `Math.random`-style nondeterminism) so app and
  widget compute byte-identical results.
- Re-running through the list after `order.count` days is acceptable for v1
  (a 1,500-word eligible pool ≈ 4 years before any repeat).
- Changing `band` reshuffles the eligible pool; we keep yesterday/today stable
  by mixing `band` into neither the salt nor the day index (band only filters).
  Edge cases (band shrank below today's word) are handled by clamping.

### 3.4 Difficulty model (grounded by the swipe deck)
- Onboarding shows ~24 words sampled across the corpus's frequency bands.
- **Right = Know (easy), Left = Don't know (hard).** We find the boundary band:
  the lowest-frequency (hardest) band where you still mostly "Know" words
  becomes your starting `band`. Concretely: per band, compute the Know-rate;
  `band = ` the hardest band whose smoothed Know-rate ≥ ~0.6.
- In-app, marking a word also nudges `band`. All of this is local; no
  word-difficulty data ever leaves the device (so this "grounds" difficulty
  *for this user*, not a crowd model — consistent with the privacy doctrine).

---

## 4. Design-system extensions (net-new to `lfwdesignsystem`)

Today the design system is **system-fonts-only** with a **fixed palette**. This
app needs variable fonts and user theming, so we add two modules to the shared
package (kept generic so the siblings could adopt them later):

### 4.1 `LFWVariableFont` — arbitrary axis control
SwiftUI's `Font.custom` can pick a family + size but **cannot** set an arbitrary
axis value (e.g. `wght = 437`); `.fontWeight` only snaps to discrete cases, and
`.fontWidth` (iOS 16) is the SF system font's width axis only. iOS 17/18 added
**no** general API. The only route is Core Text:

```swift
import CoreText
import SwiftUI

/// Pack a 4-char axis code ("wght") into its Core Text integer tag.
func lfwAxisTag(_ code: String) -> Int {
    precondition(code.count == 4)
    return code.utf8.reduce(0) { ($0 << 8) + Int($1) }   // big-endian fold
}

public extension Font {
    /// A custom variable font at arbitrary axis values, bridged into SwiftUI.
    static func lfwVariable(_ name: String, size: CGFloat,
                            axes: [Int: CGFloat]) -> Font {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: name,
            UIFontDescriptor.AttributeName(
                rawValue: kCTFontVariationAttribute as String): axes
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}
```

- Axis tags + ranges are **discovered at runtime** with
  `CTFontCopyVariationAxes` and logged once at startup (the #1 footgun is a
  wrong PostScript family name silently falling back to the system font).
- **Animation:** SwiftUI can't interpolate a `Font`. To animate an axis (e.g.
  the hero word "breathes" its weight on reveal), the axis value itself is
  `animatableData` in an `AnimatableModifier` that rebuilds the font per frame.
  Because `CTFont` creation is comparatively costly, we **cache** by quantized
  axis value (`[Int: UIFont]`) — neither off-the-shelf lib caches per frame, so
  we own a small memoizer. Animate one hero label at a time, not lists.

Reference implementations to learn from (both **MIT**, optional to vendor):
`frzi/swift-variablefonts`, `dufflink/vfont`.

### 4.2 `LFWTypography` — semantic font tokens
A token layer over the variable-font helper so screens ask for roles, not
sizes: `.heroWord`, `.partOfSpeech`, `.definition`, `.uiTitle`, `.uiBody`,
`.eyebrow`. Each role resolves the current theme's typeface + an axis preset
(e.g. `heroWord` = Fraunces `opsz:144, wght:560, SOFT:0, WONK:0`). Keeps the
existing `.rounded` system-font look available for chrome where we want family
resemblance.

### 4.3 `LFWTheme` — user-configurable palette + typeface
```swift
public struct LFWThemeConfig: Codable, Equatable {
    public var typeface: LFWTypeface   // .fraunces (default), .recursive, .literata, .inter
    public var palette: LFWPalette     // .deepSea (default), .paper, .dusk, .sepia, .highContrast
    public var accentHue: Double?      // optional fine-tune within a palette
}
```
- Persisted in the App Group defaults; **read by the widget** so app and widget
  always match.
- Presets are built **off the existing `LFWColors` family** so Deep Sea is
  literally today's onboarding gradient; we add a light "Paper" and a couple of
  alternates. Bounded set + one accent-hue control — deliberately **not** a
  free-for-all color wheel.

---

## 5. Curated fonts (all OFL 1.1, variable, app-store-safe)

Bundled as variable `.ttf`, listed in `Info.plist` `UIAppFonts`, added to
**both** targets' Copy Bundle Resources, with `OFL.txt` shipped + an
Acknowledgements screen. OFL is **not** problematic copyleft for app embedding;
it only forbids selling the font files alone and reusing reserved names.

| Font | Role | Key variable axes |
|---|---|---|
| **Fraunces** (default hero) | Display word | `wght`, `opsz`, `SOFT`, `WONK` |
| **Inter** | UI / body sans | `wght`, `opsz` (`slnt` in italic) |
| **Recursive** | Expressive alt | `wght`, `slnt`, `CASL`, `MONO`, `CRSV` |
| **Literata** / **Newsreader** | Reading serif alt | `opsz`, `wght` |

Source the variable masters from each font's GitHub repo (e.g.
`undercasetype/Fraunces /fonts/variable/`). Subset to Latin with `pyftsubset`
to shrink the bundle (one VF replaces dozens of static weights, so this still
nets smaller).

---

## 6. Screens

### 6.1 Onboarding
Reuses `LFWOnboardingBackground` + `LFWOnboardingScaffold` (hero icon, gold
kerned eyebrow, rounded-bold title) and `.preferredColorScheme(.dark)`, just
like the siblings. Flow:

1. **2–3 explainer pages** via `TabView(.page)` + `LFWPageDots` (family
   pattern): what it is, local-first promise, "let's find your level."
2. **Swipe deck** (the calibration step) — see §7.
3. **Ready** page → sets `@AppStorage` `onboardingComplete = true` (closure-based
   `onFinish`, matching `WorkoutOnboardingView`).

### 6.2 Today (in-app mirror of the widget)
The day's word large in the hero variable font, part of speech, definition,
example sentence; a **Star** toggle; a subtle weight-axis reveal animation.
Swipe/tap to peek yesterday or a "surprise me" from your band.

### 6.3 Practice
List of starred words (the Practice list). Tap → detail. Per-row Know/Don't-know
re-marking (feeds the band). An **Export** affordance (CSV) lives here — see §10.

### 6.4 Settings
Typeface picker (live preview rendering the same word across the curated VFs),
palette picker + accent-hue, plus the standard About/Acknowledgements (OFL +
wordfreq + WordNet + Gutenberg/Brown credits). Writes `LFWThemeConfig` to the App Group and reloads
the widget.

---

## 7. The Tinder swipe deck (calibration)

**Decision: hand-roll it (~120–150 lines), no dependency.** For a simple 2-way
deck the whole mechanism is `DragGesture` + `offset` + `rotationEffect` +
threshold, and no SwiftUI-native library gives *maintained + undo + 2-way
overlays* all at once. Core sketch:

```swift
@GestureState private var drag: CGSize = .zero
// top card:
.offset(x: drag.width, y: drag.height / 8)
.rotationEffect(.degrees(drag.width / 20))
.overlay(verdictBadge(opacity: min(abs(drag.width) / 120, 1),
                      know: drag.width > 0))     // green KNOW / dim DON'T-KNOW
.gesture(DragGesture()
    .updating($drag) { v, s, _ in s = v.translation }
    .onEnded { v in
        if v.translation.width >  120 { commit(.know) }
        else if v.translation.width < -120 { commit(.dontKnow) }
    })
```

Tappable Know/Don't-know buttons call the same `commit`. Undo = re-append the
last popped card. (If we ever want a library instead: `tobi404/SwipeCardsKit`,
MIT, SwiftUI-native, maintained, has programmatic swipe — but it lacks undo, so
hand-roll wins here.)

---

## 8. Widget

Mirrors `WorkoutWidget`'s `TimelineProvider` pattern.

- **Families:** `.systemSmall`, `.systemMedium`, `.systemLarge`, plus lock-screen
  `.accessoryRectangular` / `.accessoryInline` (a word is a perfect glanceable).
- **Content:** today's word in the user's variable font + palette (read from the
  App Group); medium/large add part of speech + short definition.
- **Timeline:** one entry per day; `reloadPolicy: .after(nextMidnight)` (vs. the
  workout widget's hourly backstop, because our content changes daily).
- **Tap:** `widgetURL("wordoftheday://word/\(id)")` deep-links into Today.
- **Interactive star (iOS 17):** an `AppIntent` button toggles the star straight
  from the widget and writes to the App Group — this is *why* the deployment
  target is iOS 17.
- **Read-only:** the widget target links only `Shared/` (corpus reader + theme
  + selection), never any write path — same discipline as the sibling widget.

---

## 9. Word corpus pipeline

A build-time script (`scripts/build_modern_corpus.py`) produces the 1000-word
`words.json`; the app **never** fetches anything at runtime. The corpus is
"elevated everyday" vocabulary — words picked from the **long tail of modern
English usage** (recognizable and used, not obscure GRE filler). Full source
matrix in [`docs/prior-art-and-licensing.md`](docs/prior-art-and-licensing.md):

1. **Selection + difficulty bands → wordfreq.** Take a modern English frequency
   distribution and pick 1000 words from its long tail, filtered to real WordNet
   headwords (base forms, no proper nouns / abbreviations / slurs). Split into
   five bands by frequency quintile (rarer ⇒ higher band).
2. **Definitions + part of speech → Princeton WordNet** (WordNet License,
   BSD/MIT-style; most-frequent sense of the word's dominant part of speech).
3. **Example sentences →** a real sentence using the word, preferring (a) a
   WordNet example, (b) a **Project Gutenberg** sentence (public-domain
   literature — keeps a literary flavor), (c) a **Brown Corpus** sentence
   (modern American English), then (d) a sentence written for this app
   (`scripts/examples_supplement.json`) for words too modern for those corpora.

**Licensing consequence:** wordfreq's frequency data is partly
**CC BY-SA 4.0**, so the *selection and bands* are share-alike and `words.json`
ships under **CC BY-SA 4.0** — a deliberate trade to get genuinely-used modern
words. The app source code stays MIT (see `LICENSE`). The earlier
permissive-only pipeline (WordNet × Norvig) is preserved in
`scripts/build_corpus.py` for anyone who wants a fully-permissive corpus.

**Attribution we must ship** (Acknowledgements screen + `NOTICE`): wordfreq
(CC BY-SA), WordNet, Project Gutenberg, and the Brown Corpus.

Output schema per word:
```json
{ "id": 142, "word": "laconic", "pos": "adj",
  "definition": "brief and to the point; effectively cut short",
  "example": "a laconic reply", "band": 4 }
```

---

## 10. Practice & the "someday Anki" seam

No spaced-repetition or Anki dependency now — but the data model is designed so
adding it later is a swap, not a migration:

- **Review state model is FSRS-shaped from day one** (stability, difficulty,
  due date, reps, lapses, grade enum Again/Hard/Good/Easy). FSRS is a superset
  of SM-2, and the ecosystem has converged there.
- **Export = plain CSV/TSV now.** Anki imports it natively with no add-on and
  **no AGPL exposure**; we emit `#deck`, `#notetype`, `#tags`, `#columns`
  header directives so import is one click. This satisfies "export starred words
  to Anki" today behind a small `Exporter` protocol.
- **Later, in-app practice → `open-spaced-repetition/swift-fsrs`** (MIT, native
  Swift, dependency-free). Anki itself is **AGPL** and we never link it; the
  FSRS *algorithm* org ships separately under MIT. The `.apkg` format is
  documented enough to generate permissively if we ever need media/scheduling
  round-trip, but CSV covers the 90% case for a fraction of the work.

---

## 11. Repo layout (target)

```
word-of-the-day/
  SPEC.md                      ← this file
  project.yml                  ← XcodeGen (mirrors workout-logger)
  project.local.yml.example
  lfwdesignsystem/             ← vendored; +LFWVariableFont, LFWTypography, LFWTheme
  WordOfTheDay/
    App/                       ← app entry, RootView, Theme alias
    Onboarding/                ← explainer pages + SwipeDeck
    Features/
      Today/  Practice/  Settings/
    Words/                     ← corpus reader, DailySelector, DifficultyModel
    Theme/                     ← ThemeStore (App Group defaults)
    Shared/                    ← AppGroup, SharedDefaults, WordSnapshot, Selector (widget-shared)
    Resources/                 ← words.json, fonts/*.ttf, OFL.txt, Assets
  WordWidget/                  ← TimelineProvider, views, StarIntent
  WordOfTheDayTests/
  scripts/                     ← generate.sh, run_tests.sh, check_appgroup_sync.sh,
                                 build_modern_corpus.py (+ examples_supplement.json), build_corpus.py
  docs/
    prior-art-and-licensing.md ← the "don't reinvent the wheel" research
    learnings/
  .github/workflows/           ← config-guardrails + ios-tests (from sibling repos)
```

---

## 12. Open questions / nice-to-haves

- **Repeat handling** past `order.count` days — reshuffle with a new salt, or
  start surfacing harder bands? (v1: simple wrap.)
- **Notifications** — a gentle "today's word" push? (Local only; off by default.)
- **iPad / macCatalyst** — out of scope for v1 (iPhone only, like the siblings).
- **Crowd-grounded difficulty** — deliberately excluded to honor the no-server
  doctrine; per-user grounding only.

---

## Status & scope

**Implemented.** The full vertical slice is built: XcodeGen project, the three
design-system extensions, the deterministic shared core, the app (onboarding +
swipe deck + Today + Practice + Settings), the widget (all families + interactive
star), the 1000-word corpus + build pipeline, App Store privacy manifests,
CI, and a unit-test suite over the deterministic core. The codebase is described
in `docs/learnings/001-architecture.md`. Remaining before submission: an app
icon asset, and (optionally) running `scripts/fetch_fonts.sh` to bundle the OFL
variable fonts — the app falls back to a system serif/sans without them.
