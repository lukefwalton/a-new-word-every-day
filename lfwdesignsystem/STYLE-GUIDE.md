# LFW Style Guide

The brand spec for Luke F. Walton's work — the website (`lukefwalton.com`) and the
iOS app family (Word of the Day, Private Workout Logger, Stop Political Texts, Your
Body Is an Instrument). One visual language across two mediums.

This is the **source of truth**. The Swift tokens in
`Sources/LFWDesignSystem/LFWColors.swift` and `LFWTheme.swift`, and the CSS
variables in `lukefwalton.com/src/styles/global.css`, are implementations of what
this document decides. When they disagree, this wins — then fix the code.

The rendered, human-facing version lives at **[lukefwalton.com/style](https://lukefwalton.com/style/)**.

---

## The one-line brief

**Clean, but not generic.** Worn-in and deliberate, not loud SaaS. Green is the
identity, blue is the intellect, and every color earns its place. Nothing on the
page is a framework default.

---

## Brand colors, in priority order

### 1 · Green — identity

The signature. Luke's favorite color, carried from the homepage hero. If one color
says "this is his," it's this green.

| Role | Token (Swift / CSS) | Hex | Use |
| --- | --- | --- | --- |
| **Flagship** | `forest` / `--forest` | `#1F332B` | Hero fills, the deepest surface, the identity moment. Too dark for text-on-dark or small tint. |
| **Interactive** | `verdigris` / *(app)* | `#3E8E6E` | The green that *does* things — app-wide tint, accents, active states. After *rokushō* (緑青), the ukiyo-e verdigris pigment. |
| Supporting | `--pine` | `#2F453A` | Secondary green (web). |
| Supporting | `--olive` / `--muted-text` | `#4C5242` / `#4A5249` | Utility green, olive body text (web). |

The apps' **default theme is Forest**: a deep `forest → emerald` gradient with a
gold accent (the bottom stops at a deep emerald rather than the brighter
`verdigris` tint, so `paper` text stays legible directly over the gradient).
Green primary, everywhere.

### 2 · Blue — the ukiyo-e lineage

Secondary, and deliberately **all woodblock**. No generic web-blue lives here. The
family descends from the pigments Hokusai layered in *The Great Wave off Kanagawa*:
imported Prussian blue (*bero-ai*, ベロ藍, "Berlin indigo") over the older, fading
plant indigo (*ai*, 藍).

| Role | Token (Swift / CSS) | Hex | Note |
| --- | --- | --- | --- |
| Deep | `deepSea` / — | `#002A41` | Near-black indigo. Gradient floor, shadow, contrast text on `paper`. |
| **Primary blue** | `ocean` / — | `#1F5E8C` | A lifted Prussian *bero-ai*. Powers the selectable "Deep Sea" theme. |
| Woodblock slate | `ukiyoBlue` / `--ukiyo-blue` | `#245070` | Serious, unsaturated. Links / quiet emphasis on light surfaces. |
| Highlight | `mist` / `--mist-blue` | `#7FA8B6` | Pale highlight, hairlines, soft fills. |

**Pigment lineage (documented anchors, not everyday tokens):** Prussian *bero-ai*
`#1C3F7C`, indigo *ai-iro* `#165E83`. Reach for these when a piece wants to nod
explicitly at the woodblock source.

> Note the retune: `ocean` was a bright modern web-blue (`#1D75BC`) — the one
> generic color in the system. It's now a woodblock Prussian so the whole blue
> family tells one story.

### 3 · Restraint & warmth (supporting accents)

| Role | Token (Swift / CSS) | Hex | Use |
| --- | --- | --- | --- |
| Kicker / CTA | `gold` / `--brass` | `#FFCD34` / `#B89058` | The premium accent, used sparingly. Warm gold in-app, muted brass on the web. Same *role*, tuned per medium. |
| Rare warmth | `--rust` | `#9F5C4A` | Web only. Not a primary; a little heat. |
| Rarest accent | `--jacaranda` | `#6E6597` | Web only. San Diego in bloom — use it once, somewhere personal. Never a link, gradient, or primary, or it tips into SaaS purple. |
| Decorative | `traveler` / `nebula` / `kelp` | `#6B5AA6` / `#92278F` / `#60C3A3` | In-app gradient blobs and secondary highlights. |

### Surfaces & ink — intentionally different by medium

The two mediums keep **different surface temperatures**, on purpose, and that's
documented rather than forced identical:

- **Web is warm** — rice-paper `--bg #F4EEDD`, parchment `--surface #E8E0CB`,
  green-black ink `--text #111714`. Editorial, printed, calm.
- **App is cool** — glassy `paper #EFF9FE` over dark themed gradients, ink
  `#071D2B`. Screen-native, luminous.

Green is the through-line that makes them read as one brand despite the different
paper.

### Status colors (app)

On-palette, not system `.red`/`.orange`/`.green`: `success #2E9E74`,
`warning #E0912F`, `danger #D1495B`.

---

## Fonts, by purpose

Standardized by **intent, not by "one font everywhere."** Three purposes, three
faces, each chosen. All are variable OFL fonts already in the system.

| Purpose | Face | Where | Why |
| --- | --- | --- | --- |
| **Display / expressive** | **Fraunces** (`opsz`, `SOFT`, `WONK`) | App hero word, big titles, personality moments | Has character and wonk — the signature voice, never generic. The app default. |
| **Prose / long-form** | **Literata** (`opsz`, `ital`) | Website body, essays, definitions, reading | A bookish, comfortable serif built for reading at length. |
| **UI / functional** | **Inter** | App chrome, settings, buttons, HUD, mobile-onboarding body, numerals | Neutral clarity where a serif would be fussy or slow to scan. |
| **Japanese** | **Noto Serif JP** (paired with Literata) | `/jp` | Covers kana/kanji; matches Literata's editorial weight. |

Rule of thumb: **prose-heavy surfaces read in Literata; expressive moments speak in
Fraunces; functional chrome works in Inter.** A screen may mix them by role (a
Fraunces title over Inter controls), but never picks a face at random.

Type roles and their variable-axis weights live in
`Sources/LFWDesignSystem/LFWTypography.swift` (`LFWTextRole`); the web scale lives
in `global.css`.

---

## Using this

- **In an app:** reach for `LFWColors.*` and `LFWTypography.font(_:typeface:)` /
  `LFWTextRole` — never a raw hex or a system `.green`. New brand color? Add it
  here first, then to `LFWColors.swift`, then bump `VERSION` and run
  `scripts/sync_designsystem.sh`.
- **On the web:** use the `--var`s in `global.css`; don't hardcode hexes in pages.
- **Keep the two in sync in spirit, not byte-for-byte** — the medium temperatures
  differ on purpose (see Surfaces).
