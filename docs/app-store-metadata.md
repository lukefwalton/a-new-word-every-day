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

## What's New (build 5 — paste for this resubmission)

```
• Japanese vocabulary — 7,800+ JLPT words alongside English
• Enable English, Japanese, or both in Settings
• Per-widget language via Edit Widget
• Smarter study scheduling (FSRS-6) and fresh word pools each cycle
• Widget preview and medium-widget layout fixes (Rich detail no longer clips)
• Bug fixes and stability improvements
```

## Reply to App Review (metadata fix)

```
We removed all price references from the app subtitle and promotional text.
The subtitle is now "English & Japanese vocabulary." Thank you for the review.
```

## Resubmission checklist (July 2026)

Local prep (done on this machine):

- [x] Tests pass (`bash scripts/run_tests.sh`)
- [x] Release archive **1.0 (5)** → `build/WordOfTheDay.xcarchive`
- [x] Screenshots refreshed → `build/app-store-screenshots/{iphone,ipad}/` (Jul 8, after preview fix)

You still need to do in App Store Connect + Xcode:

1. **Metadata** — Subtitle → `English & Japanese vocabulary`. Remove "Free" from promotional text and description (see above). Support/Privacy URLs in their dedicated fields only.
2. **Upload** — Xcode → Organizer → Distribute App → App Store Connect.
3. **Version** — Attach build **1.0 (5)** to the existing 1.0 submission.
4. **Screenshots** — Re-upload iPhone 6.5" and iPad 13" sets from `build/app-store-screenshots/{iphone,ipad}/{en,ja}/`. App Store allows 10 per size — a good order: EN Today, JA Today, EN Settings, JA Settings, Practice (either language).
5. **What's New** — Paste the block above.
6. **Reply** — Optional note to App Review (paste block above), then **Add for Review**.
