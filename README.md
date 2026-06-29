# Word of the Day

A free, local-first iOS app + Home Screen / Lock Screen **widget** that teaches
one elevated English word a day — beautiful variable type, your colors, no login,
nothing ever leaves your phone.

> **No account. No servers. No tracking. No analytics.** Everything — your stars,
> your difficulty level, your theme — lives on device in an App Group store the
> app and widget share. The app makes zero network calls at runtime.

## What it does

- **A new word every day** on the widget (small / medium / large + lock screen),
  rendered in a configurable [variable font](docs/prior-art-and-licensing.md)
  (Fraunces by default) and color theme.
- **Star** a word — from the app *or* straight from the widget (iOS 17
  interactive button) — to save it to a **Practice** list.
- **Tinder-style swipe onboarding** that calibrates your difficulty level on
  first launch (swipe right = "I know it", left = "new to me"), entirely
  on-device.
- **Export to Anki** as native CSV whenever you like (no Anki code, no AGPL).

## Architecture

- **Deterministic daily word** — the word is a pure function of (date, per-install
  seed, difficulty band, corpus), so the widget computes the exact same word the
  app shows with no shared write. See `WordOfTheDay/Shared/DailySelector.swift`.
- **`lfwdesignsystem`** — the family design system (vendored Swift Package),
  extended here with variable-font axis control (`LFWVariableFont`, Core Text),
  semantic typography (`LFWTypography`), and user theming (`LFWThemeConfig`).
- **Widget** — `WidgetKit` timeline that reloads at midnight; reads the shared
  store; never links any write path beyond the interactive star intent.
- **Corpus** — 1000 "elevated everyday" words (`WordOfTheDay/Resources/words.json`),
  picked from the long tail of modern English usage. Built offline by
  `scripts/build_modern_corpus.py`: selection + difficulty bands from
  [wordfreq](https://github.com/rspeer/wordfreq), definitions from WordNet, and
  example sentences from public-domain literature (Project Gutenberg) and the
  Brown Corpus. Because wordfreq's data is share-alike, **the bundled word list
  is CC BY-SA 4.0** (the app code stays MIT). See
  [docs/prior-art-and-licensing.md](docs/prior-art-and-licensing.md).

See [SPEC.md](SPEC.md) for the full design and
[docs/learnings/001-architecture.md](docs/learnings/001-architecture.md) for the
shape of the codebase.

## Build

```bash
brew install xcodegen
python3 -m pip install pyyaml                      # generate.sh merges YAML with PyYAML
cp project.local.yml.example project.local.yml   # set DEVELOPMENT_TEAM
bash scripts/fetch_fonts.sh                       # optional: OFL variable fonts
bash scripts/generate.sh
open WordOfTheDay.xcodeproj
```

Register the App Group (`group.com.lukewalton.wordoftheday`) for your team. For a
fork, change `bundleIdPrefix` / bundle IDs in `project.local.yml` and the App
Group in both `.entitlements` files plus `AppGroup.identifier` (CI checks they
match). The app runs without the fonts — it falls back to a system serif/sans.

## Test

```bash
bash scripts/run_tests.sh
```

The deterministic core (daily selection, difficulty calibration, store,
exporter, scheduler, corpus integrity) is covered by `WordOfTheDayTests`; CI
(`.github/workflows`) runs the suite on macOS and config guardrails on Linux.

## License

Code: MIT, see [LICENSE](LICENSE). Bundled fonts are SIL OFL 1.1. The bundled
word list (`WordOfTheDay/Resources/words.json`) is **CC BY-SA 4.0**, because its
selection derives from wordfreq's share-alike frequency data. Full attribution
and per-source terms: see [NOTICE](NOTICE).
