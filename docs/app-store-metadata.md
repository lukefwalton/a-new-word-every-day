# App Store metadata — A New Word Every Day

Compliant copy for App Store Connect. **Do not use "Free", "$0", or other price
language in the subtitle, name, or promotional text** — Apple Guideline 2.3.7
(rejection July 2026). Price belongs in the description body only.

## Subtitle (≤30 chars)

**Use:** `Private. No account.`

Alternates:
- `Nothing leaves your phone.`
- `Local-only. No account.`
- `One word. On your phone.`

**Rejected:** `Free. Private. No account.`

## Promotional text (≤170 chars, optional)

```
One rare word a day on your Home Screen — English, Japanese, or both. Beautiful type, your colors. Private, no account. Nothing leaves your phone.
```

## Description section headers

Replace `FREE. PRIVATE. NO ACCOUNT.` with:

```
PRIVATE. NO ACCOUNT.
```

Keep pricing in prose if needed: "No subscription or in-app purchases" is fine
in the description body; avoid leading with "Free" as a headline.

## Description (full body — paste into App Store Connect)

```
PRIVATE. NO ACCOUNT.

One rare word a day on your Home Screen — English, Japanese, or both. Beautiful variable typefaces, your colors, your widget layout. Nothing leaves your phone.

• Home Screen & Lock Screen widgets (small, medium, large)
• English vocabulary (1,100+ elevated words) and Japanese JLPT vocabulary (7,800+ words)
• Enable either language or both; set widget language per widget
• Star words from the app or straight from the widget (iOS 17+)
• Optional spaced-repetition study for starred words (FSRS-6)
• Seven OFL variable fonts and customizable palettes
• Export starred words to Anki

No account. No ads. No analytics. No network requests at runtime. No subscription or in-app purchases.

Support: https://lukefwalton.com/a-new-word-every-day/
Privacy: https://lukefwalton.com/a-new-word-every-day/privacy/
```

## Keywords (optional, ≤100 chars)

```
vocabulary,japanese,jlpt,english,widget,dictionary,words,learn,anki,language
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

## What's New (build 4 — paste for this resubmission)

```
• Japanese vocabulary — 7,800+ JLPT words alongside English
• Enable English, Japanese, or both in Settings
• Per-widget language via Edit Widget
• Smarter study scheduling (FSRS-6) and fresh word pools each cycle
• Widget preview and layout fixes
• Bug fixes and stability improvements
```

## Reply to App Review (metadata fix)

```
We removed all price references from the app subtitle and promotional text.
The subtitle is now "Private. No account." Thank you for the review.
```

## Resubmission checklist (July 2026)

Local prep (done on this machine):

- [x] Tests pass (`bash scripts/run_tests.sh`)
- [x] Release archive **1.0 (4)** → `build/WordOfTheDay.xcarchive`
- [x] Screenshots refreshed → `build/app-store-screenshots/{iphone,ipad}/`

You still need to do in App Store Connect + Xcode:

1. **Metadata** — Subtitle → `Private. No account.` Remove "Free" from promotional text and description headers (see above).
2. **Upload** — Xcode → Organizer → Distribute App → App Store Connect.
3. **Version** — Attach build **1.0 (4)** to the existing 1.0 submission.
4. **Screenshots** — Re-upload iPhone 6.5" and iPad 13" sets (UI changed: languages, green theme).
5. **What's New** — Paste the block above.
6. **Reply** — Optional note to App Review (paste block above), then **Add for Review**.
