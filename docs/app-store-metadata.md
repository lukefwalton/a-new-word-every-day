# App Store metadata — A New Word Every Day

Compliant copy for App Store Connect. **Do not use "Free", "$0", or other price
language in the subtitle, name, or promotional text** — Apple Guideline 2.3.7
(rejection July 2026). Price belongs in the description body only.

## Subtitle (≤30 chars)

**Use:** `English & Japanese vocabulary`

Alternates:
- `Private. No account.`
- `Nothing leaves your phone.`
- `Local-only. No account.`

**Rejected:** `Free. Private. No account.`

## Promotional text (≤170 chars, optional)

```
One rare word a day on your Home Screen — English, Japanese, or both. Beautiful type, your colors. Private, no account. Nothing leaves your phone.
```

## Description (full body — paste into App Store Connect)

No URLs in the description — Support and Privacy URLs go in their own fields.

```
A New Word Every Day surfaces one rare, useful word each day — English, Japanese, or both — with an original one-line definition and beautiful variable typography.

A BEAUTIFUL WIDGET
Add a small, medium, large, or extra-large widget (or a Lock Screen accessory). Pick your typeface, palette, accent hue, layout, and how much definition to show. Set widget language per widget. The word updates daily without opening the app.

PRIVATE. NO ACCOUNT.
No subscription. No ads. No analytics. No login. Stars, per-language difficulty, theme, and optional study schedules stay on your iPhone in a local App Group shared only with the widget.

LEARN YOUR WAY
• Enable English, Japanese, or both — each with its own daily word and difficulty level
• Swipe onboarding calibrates your level per language
• Star words from the app or directly from the widget (iOS 17+)
• Optional FSRS spaced-repetition study for starred words
• Export starred words to Anki as CSV

Built for people who want one good word a day, not another feed, account, or cloud sync.

For advanced English vocabulary, JLPT study, or both.

Open source (MIT). English word list: public domain (CC0). Japanese headwords and readings: Tanos (CC BY); definitions original to this app.
```

## Keywords (≤100 chars, comma-separated, no spaces after commas)

Apple already indexes your **name** and **subtitle** — don't waste chars on `word`, `day`, or `english` if subtitle is `English & Japanese vocabulary`.

**Use (99 chars):**
```
japanese,jlpt,vocabulary,widget,offline,privacy,anki,gre,sat,daily,education,kanji,study,fsrs,n5,n4
```

## Review notes (paste into App Review)

```
No login or network required. Review entirely offline.

First launch: tap "Skip" on onboarding (or swipe a few cards to calibrate).

Main flows: Today (daily word), Practice (starred words + optional study), Settings (typeface, palette, widget, languages).

Languages: Settings → Languages to enable English and/or Japanese. Widget language can be set per widget via Edit Widget.

Widget: add from Home Screen; star works without opening the app (iOS 17+).

No IAP, no ads, no analytics. All data stays on-device.
```

## URLs

| Field | URL |
|-------|-----|
| Support | https://lukefwalton.com/a-new-word-every-day/ |
| Privacy | https://lukefwalton.com/a-new-word-every-day/privacy/ |

## What's New (1.3 / build 9 — paste for this update)

```
• Marking a word "New to me" saves it to Practice
• Today’s language label wraps instead of cutting off
```

## 1.3 update checklist (October 2026)

Local prep:

- [x] Tests pass + Release archive **1.3 (9)** → `bash scripts/release.sh` → `build/WordOfTheDay.xcarchive`
- [ ] Upload build **9** from Xcode Organizer (CLI has no App Store Connect session)
- [x] Screenshots — reuse existing sets

You still need to do in App Store Connect:

1. **Version** — Create **1.3** (do not attach this build to the 1.2 version).
2. **What's New** — Paste the block above.
3. **Build** — It will not appear on the version page until TestFlight finishes processing. Then use **+** in the Build section and pick **1.3 (9)**.
4. **Review notes** — Reuse the offline / no-login block above.
5. **Submit** — **Add for Review**.

Subtitle stays `English & Japanese vocabulary` (never put Free/price in name, subtitle, or promo text — Guideline 2.3.7). No full metadata rewrite required for this update.
