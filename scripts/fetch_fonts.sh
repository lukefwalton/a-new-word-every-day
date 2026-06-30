#!/usr/bin/env bash
#
# ============================================
# Purpose:           Download the OFL 1.1 variable fonts into WordOfTheDay/Resources/Fonts/.
# When to use:       Before a release build, or any build that needs the bundled fonts.
# Safe to run in prod?  Yes — network download into a gitignored local folder; nothing committed.
# Owner:             Luke F. Walton
# ============================================
#
# Fetch the OFL 1.1 variable fonts into WordOfTheDay/Resources/Fonts/.
#
# The fonts are NOT committed (kept out of git via .gitignore) to keep the repo
# light and avoid vendoring binaries; this script downloads the variable .ttf
# masters straight from each typeface's source repo. All seven are SIL Open Font
# License 1.1 — free to embed in an app binary; we ship OFL.txt + an in-app
# Acknowledgements credit. The app runs without them too: the typography layer
# falls back to a system serif/sans (see LFWTypography), so onboarding and tests
# don't depend on this step.
#
# Run from anywhere:  bash scripts/fetch_fonts.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="WordOfTheDay/Resources/Fonts"
mkdir -p "$DEST"

# name|url  (variable masters; the family's runtime name must match LFWTypeface.family)
FONTS=(
  "Fraunces.ttf|https://github.com/undercasetype/Fraunces/raw/master/fonts/variable/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
  "Literata.ttf|https://github.com/googlefonts/literata/raw/main/fonts/variable/Literata%5Bopsz%2Cwght%5D.ttf"
  "Newsreader.ttf|https://github.com/productiontype/Newsreader/raw/master/fonts/variable/ttf/Newsreader%5Bopsz%2Cwght%5D.ttf"
  "SourceSerif4.ttf|https://github.com/adobe-fonts/source-serif/raw/release/VAR/SourceSerif4Variable-Roman.ttf"
  "Inter.ttf|https://github.com/rsms/inter/raw/master/docs/font-files/InterVariable.ttf"
  "SourceSans3.ttf|https://github.com/adobe-fonts/source-sans/raw/release/VF/SourceSans3VF-Upright.ttf"
  "Recursive.ttf|https://github.com/arrowtype/recursive/raw/main/fonts/ArrowType-Recursive-1.085/Recursive_Desktop/Recursive_VF_1.085.ttf"
)

# NOTE: URLs point at each font's source branch (master/main), which can move.
# For a reproducible setup, pin to a release asset or commit SHA and verify a
# checksum. We fail non-zero on ANY download problem so a partial fetch can't
# look successful.
failed=0
for entry in "${FONTS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  echo "↓ $name"
  if curl -fsSL "$url" -o "$DEST/$name"; then
    echo "  ✓ $DEST/$name"
  else
    echo "  ✗ failed — update the URL in scripts/fetch_fonts.sh (source repos move files)" >&2
    rm -f "$DEST/$name"   # don't leave a truncated/partial file behind
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "One or more fonts failed to download. The app still runs (system fallback)," >&2
  echo "but fix the URLs above before relying on the bundled typefaces." >&2
  exit 1
fi

cat <<'NOTE'

Done. Next:
  1. Confirm the runtime family names (a VF registers under its default named
     instance). In a debug build, LFWVariableFont.axes(of: "Fraunces") logs the
     real family + axes — if it's empty, fix LFWTypeface.family / UIAppFonts.
  2. The font files are already listed in WordOfTheDay/App/Info.plist (UIAppFonts)
     and bundled via the Resources group in project.yml.
NOTE
