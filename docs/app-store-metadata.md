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
One rare English word a day on your Home Screen — beautiful type, your colors. Private, no account. Nothing leaves your phone.
```

## Description section headers

Replace `FREE. PRIVATE. NO ACCOUNT.` with:

```
PRIVATE. NO ACCOUNT.
```

Keep pricing in prose if needed: "No subscription or in-app purchases" is fine
in the description body; avoid leading with "Free" as a headline.

## Review notes (paste into App Review)

```
No login or network required. Review entirely offline.

First launch: tap "Skip" on onboarding (or swipe a few cards to calibrate).

Main flows: Today (daily word), Practice (starred words + optional study), Settings (typeface, palette, widget).

Widget: add from Home Screen; star works without opening the app (iOS 17+).

No IAP, no ads, no analytics. All data stays on-device.
```

## URLs

| Field | URL |
|-------|-----|
| Support | https://lukefwalton.com/a-new-word-every-day/ |
| Privacy | https://lukefwalton.com/a-new-word-every-day/privacy/ |

## What's New (build 2 — paste for this resubmission)

```
• Fresh word pool each study cycle — less repetition over time
• Smarter study scheduling (FSRS-6)
• Refreshed green look and accessibility polish
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
- [x] Release archive **1.0 (2)** → `build/WordOfTheDay.xcarchive`
- [x] Screenshots refreshed → `build/app-store-screenshots/{iphone,ipad}/`

You still need to do in App Store Connect + Xcode:

1. **Metadata** — Subtitle → `Private. No account.` Remove "Free" from promotional text and description headers (see above).
2. **Distribution cert** — Keychain only has Apple Development. In Xcode → Settings → Accounts → Manage Certificates, add **Apple Distribution**, then re-archive if Organizer rejects the upload.
3. **Upload** — Xcode → Organizer → `WordOfTheDay.xcarchive` → Distribute App → App Store Connect.
4. **Version** — Attach build **1.0 (2)** to the existing 1.0 submission (or create new version if needed).
5. **Screenshots** — Upload iPhone 6.5" and iPad 13" sets from `build/app-store-screenshots/` if the listing still shows old UI.
6. **What's New** — Paste the block above.
7. **Reply** — Optional note to App Review (paste block above), then **Add for Review**.
