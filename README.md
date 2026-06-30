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
- **Corpus** — a hand-authored list of elevated/advanced words
  (`WordOfTheDay/Resources/words.json`): each entry is a word, an original
  one-line definition, and a difficulty band (1–5). It's written for this app
  with **no external data** (no frequency list, no licensed dictionary, no
  scraped text) and dedicated to the **public domain (CC0)** — free for anyone
  to reuse. Edit `scripts/corpus_source.json` and run `scripts/build_corpus.py`
  to regenerate. See [docs/prior-art-and-licensing.md](docs/prior-art-and-licensing.md).

See [SPEC.md](SPEC.md) for the full design and
[docs/learnings/001-architecture.md](docs/learnings/001-architecture.md) for the
shape of the codebase.

## Build

```bash
brew install xcodegen
python3 -m pip install pyyaml                      # generate.sh merges YAML with PyYAML
cp project.local.yml.example project.local.yml   # set DEVELOPMENT_TEAM
bash scripts/fetch_fonts.sh                       # required for release (OFL variable fonts)
bash scripts/generate.sh
open WordOfTheDay.xcodeproj
```

Register the App Group (`group.com.lukewalton.wordoftheday`) for your team. For a
fork, change `bundleIdPrefix` / bundle IDs in `project.local.yml` and the App
Group in both `.entitlements` files plus `AppGroup.identifier` (CI checks they
match). Without bundled fonts the app falls back to system serif/sans.

## App Store (free, no IAP)

```bash
cp project.local.yml.example project.local.yml   # or: bash scripts/setup_signing.sh
bash scripts/release.sh                            # fonts + tests + Release archive
```

In App Store Connect:

| Field | Value |
|-------|--------|
| **Price** | Free |
| **Support URL** | https://lukefwalton.com/a-new-word-every-day/ |
| **Privacy Policy** | https://lukefwalton.com/a-new-word-every-day/privacy/ |
| **App Privacy** | Data Not Collected |
| **Export compliance** | No (ITSAppUsesNonExemptEncryption is false) |
| **Screenshots** | Include the Home Screen widget — it's the product |

Review notes: no login, no network, widget star works without opening the app.
Register App Group on both app and widget App IDs in the Developer portal.

## Test

```bash
bash scripts/run_tests.sh
```

The deterministic core (daily selection, difficulty calibration, store,
exporter, scheduler, corpus integrity) is covered by `WordOfTheDayTests`; CI
(`.github/workflows`) runs the suite on macOS and config guardrails on Linux.

## License

Code: MIT, see [LICENSE](LICENSE). Bundled fonts are SIL OFL 1.1. The word list
(`WordOfTheDay/Resources/words.json`) is original work dedicated to the **public
domain (CC0)** — no copyleft, no attribution required. See [NOTICE](NOTICE).
