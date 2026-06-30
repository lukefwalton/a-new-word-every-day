# Prior art & licensing — don't reinvent the wheel

Where this app reuses existing, well-solved work, and the license of each
choice. The guiding rule for **application code** is **permissive only**
(MIT / Apache / BSD / ISC / public-domain / WordNet License / SIL OFL).

> **Update (2026) — final decision: the word list is original and public-domain.**
> After a detour through a share-alike source (`wordfreq`), the owner's call was
> not to gatekeep the dictionary behind copyleft at all. So the word list is now
> **hand-authored** — every headword, definition, and difficulty band written for
> this app, with **no external data** — and dedicated to the **public domain
> (CC0)**. No frequency list, no third-party dictionary, no scraped text, no
> attribution required. This is the permissive-only principle below taken to its
> conclusion: the cleanest way to avoid every license question is to own the data.
> The source of record is `scripts/corpus_source.json`. The matrix below is kept
> as a record of the sources evaluated along the way.

License verifications below were done by reading the actual LICENSE files /
canonical license pages (mid-2026), not from memory. Re-verify before vendoring.

---

## 1. Word data (the corpus)

| Source | Contains | License | Verdict |
|---|---|---|---|
| **Princeton WordNet** | Definitions, POS, synsets, many example sentences (~117k synsets) | **WordNet License** (OSI-approved, BSD/MIT-style; attribution notice required; **not** share-alike) | ✅ **Primary source.** Commercial app bundling explicitly allowed. |
| **Norvig `count_1w.txt`** (Google Web Trillion Word Corpus counts) | Word → frequency count | **MIT** | ✅ **Difficulty ranking.** Rarer ⇒ harder band. |
| **SCOWL** / English Speller DB | Word inventory + commonness tiers (no defs) | Permissive (MIT/BSD-compatible) | ✅ Headword filter / coarse difficulty. |
| **dwyl/english-words** | ~466k words (no defs) | **Unlicense (PD)** | ✅ Optional membership/spell filter. |
| **Webster's 1913** | Dictionary text | **Public domain** (re-derive JSON from Gutenberg to dodge GPL-packaged repos) | ⚠️ Fallback only — archaic, no POS, no modern words. |
| Wordset Dictionary | Defs/POS/examples (~25k) | **CC-BY-SA 4.0** | ❌ Share-alike — avoid. |
| Wiktionary / **dictionaryapi.dev** (Free Dictionary API) | Defs | **CC-BY-SA** data (+ GPL API code) | ❌ Share-alike — avoid bundling. Fine for live lookups only. |
| GCIDE | Dictionary | **GPL** | ❌ Copyleft — avoid. |
| `wordfreq` bundled data / SUBTLEX-US | Frequencies | **CC-BY-SA / "SA-like"** | ✅ **Now adopted** for selection + bands (see amended build). Makes `words.json` CC-BY-SA. |
| **Brown Corpus** | Present-day American English sentences | Brown University; "redistribution permitted" | ✅ Example sentences for modern words absent from public-domain literature. |
| Scraped GRE repos (Magoosh/Barron's/Manhattan) | GRE word lists | **No license** + derived from proprietary prep | ❌ Use only as headword *inspiration*; re-source defs from WordNet. |

**Approaches evaluated (all superseded):**

- *Permissive-only:* WordNet (defs/POS) × Norvig `count_1w` (bands), headwords
  from SCOWL/GRE tiers. Norvig is fetched at build time and is now frequently
  blocked behind site policies.
- *Modern long-tail:* a `wordfreq` distribution → 1000 long-tail words → WordNet
  definitions → example sentences from Gutenberg/Brown/authored. Worked, but
  wordfreq's data is partly **CC BY-SA**, which would have made `words.json`
  share-alike — copyleft we chose not to inherit.

**Shipping build — `scripts/build_corpus.py`:** none of the above. The word list
is **hand-authored and dedicated to the public domain (CC0)**: every headword,
definition, and difficulty band is original work in `scripts/corpus_source.json`,
with no external data of any kind. `build_corpus.py` just validates and numbers
it. No attribution, no share-alike, nothing to gatekeep.

---

## 2. Fonts (variable, OFL 1.1 — app-store-safe)

All **SIL Open Font License 1.1**. OFL is *not* problematic copyleft for app
embedding: you may bundle the `.ttf` in a binary freely; you may **not** sell the
font files alone or reuse the reserved font names. Ship `OFL.txt` + an
Acknowledgements credit.

| Font | Role | Variable axes | Repo |
|---|---|---|---|
| **Fraunces** | Hero / display (default) | `wght`, `opsz`, `SOFT`, `WONK` (italic is a separate VF) | `undercasetype/Fraunces` |
| **Inter** | UI / body sans | `wght`, `opsz` (+ `slnt` italic) | `rsms/inter` |
| **Recursive** | Expressive alt (one file = sans + mono) | `wght`, `slnt`, `CASL`, `MONO`, `CRSV` | `arrowtype/recursive` |
| **Literata** | Reading serif | `opsz`, `wght` | `googlefonts/literata` |
| **Newsreader** | Reading serif | `opsz`, `wght` | `productiontype/Newsreader` |
| **Source Serif 4** | Text serif | `opsz`, `wght` | `adobe-fonts/source-serif` |
| **Source Sans 3** | UI sans alt | `wght` | `adobe-fonts/source-sans` |

**Embedding gotchas:** add each file to `UIAppFonts` *and* the target's Copy
Bundle Resources; the runtime PostScript family name is the VF's *default named
instance* — print `UIFont.fontNames(forFamilyName:)` once to get the exact
string (wrong name ⇒ silent system-font fallback). Subset to Latin with
`pyftsubset` to shrink the bundle.

---

## 3. Variable-font axis control in SwiftUI

**Finding:** there is **no** first-class SwiftUI/iOS API to set arbitrary
variation-axis values on a custom font. `Font.custom` only picks family+size;
`.fontWeight` snaps to discrete cases; `.fontWidth` (iOS 16) is the SF system
font's width axis only; **iOS 17/18 added nothing.** The only route is Core Text.

**Working approach** (see `SPEC.md` §4.1 for the full helper):
- Build a `UIFont` from a `UIFontDescriptor` carrying
  `kCTFontVariationAttribute` = `[axisTag: value]`, where `axisTag` is the
  4-char code folded big-endian into an `Int` (`wght` = `0x77676874`).
- Bridge to SwiftUI with `Font(uiFont)`.
- Discover real tags + ranges with `CTFontCopyVariationAxes`.
- **Animate** by making the axis value `animatableData` in an
  `AnimatableModifier` (SwiftUI can't interpolate a `Font`); **cache** built
  fonts by quantized axis value because `CTFont` creation is per-frame costly.

**Reference libs (MIT, optional):** `frzi/swift-variablefonts` (gives
`Font.custom(name:size:axes:)`), `dufflink/vfont` (animation pattern). We can
vendor or just copy the ~40-line helper.

---

## 4. Swipe / Tinder card deck

**Decision: hand-roll (~120–150 lines).** A 2-way `DragGesture` + `offset` +
`rotationEffect` deck is small, and no SwiftUI-native lib offers *maintained +
2-way overlays + undo* together.

| Option | License | SwiftUI-native | Maintained | Notes |
|---|---|---|---|---|
| **Hand-rolled** | — | ✅ | — | **Chosen.** Full control, zero deps, includes undo. |
| `tobi404/SwipeCardsKit` | **MIT** | ✅ | ✅ (2025, Swift 6) | Best lib pick; programmatic swipe via `popTrigger`; **no undo**. |
| `dadalar/SwiftUI-CardStackView` | **MIT** | ✅ | ❌ (stale 2022) | Popular but frozen; no programmatic swipe/undo API. |
| `mac-gallagher/Shuffle` | **MIT** | ❌ UIKit | ❌ (2021) | Has undo, but UIKit bridge + abandoned. |
| `JayantBadlani/TinderCardSwiperSwiftUI` | **none** | ✅ | — | ❌ No LICENSE = all rights reserved. Avoid. |

---

## 5. Spaced repetition / Anki export

Anki itself is **AGPL-3.0** — we never link its code. Everything we need is
available permissively.

| Need | Choice | License |
|---|---|---|
| Export starred words to Anki **now** | Plain **CSV/TSV** with `#deck`/`#notetype`/`#tags`/`#columns` headers (Anki imports natively, no add-on) | n/a — our own writer |
| In-app scheduling **later** | `open-spaced-repetition/swift-fsrs` (FSRS-6, native, dependency-free) | **MIT** |
| Alt SR ports | `4rays/swift-fsrs`, `bootuz/SwiftFSRS` | **MIT** |
| Classic algorithm | SM-2 — published algorithm, free to implement; add `Algorithm SM-2, (C) Copyright SuperMemo World, 1991` attribution | n/a (algorithm, not code) |
| `.apkg` export (only if we need media/scheduling round-trip) | Format is a ZIP-of-SQLite, documented enough to generate without Anki code | format not copyrightable |

**Plan:** ship a CSV `Exporter` now; design review-state **FSRS-shaped** so
adopting `swift-fsrs` later is a swap, not a migration. No AGPL enters the app.

---

## Sources

**Word data**
- WordNet license: https://wordnet.princeton.edu/license-and-commercial-use · https://opensource.org/license/wordnet
- Norvig count_1w (MIT): https://norvig.com/ngrams/ · https://norvig.com/ngrams/count_1w.txt
- SCOWL: https://github.com/en-wl/wordlist · https://wordlist.aspell.net/
- dwyl/english-words (Unlicense): https://github.com/dwyl/english-words
- Webster's 1913 JSON: https://github.com/matthewreagan/WebstersEnglishDictionary
- Wordset (CC-BY-SA, avoid): https://github.com/wordset/wordset-dictionary
- Free Dictionary API (CC-BY-SA data, avoid bundling): https://dictionaryapi.dev/

**Fonts**
- Fraunces: https://github.com/undercasetype/Fraunces · https://fonts.google.com/specimen/Fraunces
- Inter: https://github.com/rsms/inter · Recursive: https://github.com/arrowtype/recursive
- Literata: https://github.com/googlefonts/literata · Newsreader: https://github.com/productiontype/Newsreader · Source Serif: https://github.com/adobe-fonts/source-serif

**Variable fonts in SwiftUI**
- Moving Parts, fonts in SwiftUI: https://movingparts.io/fonts-in-swiftui
- frzi/swift-variablefonts (MIT): https://github.com/frzi/swift-variablefonts
- dufflink/vfont (MIT): https://github.com/dufflink/vfont
- Variable fonts on macOS w/ SwiftUI: https://mike-engel.com/writing/variable-fonts-on-macos-with-swiftui/

**Swipe decks**
- tobi404/SwipeCardsKit (MIT): https://github.com/tobi404/SwipeCardsKit
- dadalar/SwiftUI-CardStackView (MIT): https://github.com/dadalar/SwiftUI-CardStackView
- mac-gallagher/Shuffle (MIT, UIKit): https://github.com/mac-gallagher/Shuffle

**Spaced repetition / Anki**
- open-spaced-repetition org: https://github.com/open-spaced-repetition
- swift-fsrs (MIT): https://github.com/open-spaced-repetition/swift-fsrs · https://github.com/4rays/swift-fsrs · https://github.com/bootuz/SwiftFSRS
- SM-2 license: https://supermemopedia.com/wiki/Licensing_SuperMemo_Algorithm · https://www.supermemo.guru/wiki/Algorithm_SM-2
- Anki CSV import: https://docs.ankiweb.net/importing/text-files.html
- .apkg format: https://eikowagenknecht.com/posts/understanding-the-anki-apkg-format/
