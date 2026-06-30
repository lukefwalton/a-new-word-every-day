#!/usr/bin/env bash
#
# ============================================
# Purpose:           Fetch fonts, run tests, and archive a Release build for App Store upload.
# When to use:       When cutting an App Store build.
# Safe to run in prod?  Yes, with caution — produces the shippable archive; run on a clean, signed checkout.
# Owner:             Luke F. Walton
# ============================================
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Fonts"
if ! compgen -G "WordOfTheDay/Resources/Fonts/*.ttf" > /dev/null; then
  bash scripts/fetch_fonts.sh
fi

echo "==> Project"
if [ -f project.local.yml ]; then
  bash scripts/generate.sh
else
  echo "Create project.local.yml with your DEVELOPMENT_TEAM first." >&2
  echo "  cp project.local.yml.example project.local.yml" >&2
  echo "  bash scripts/setup_signing.sh   # auto-detect team" >&2
  exit 1
fi

echo "==> Tests"
bash scripts/run_tests.sh

ARCHIVE="${1:-build/WordOfTheDay.xcarchive}"
mkdir -p "$(dirname "$ARCHIVE")"

echo "==> Archive (Release) → $ARCHIVE"
xcodebuild archive \
  -scheme WordOfTheDay \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates

echo ""
echo "Done. Next steps:"
echo "  1. Xcode → Window → Organizer → Distribute App"
echo "  2. App Store Connect: Support URL → https://lukefwalton.com/a-new-word-every-day/"
echo "  3. Privacy Policy URL → https://lukefwalton.com/a-new-word-every-day/privacy/"
echo "  4. App Privacy: Data Not Collected"
echo "  5. Screenshots: include Home Screen widget"
echo "  6. App name: A New Word Every Day (subtitle: Free. Private. No account.)"
echo "  7. Review notes: local-only app, no login, widget star works without opening app"
