#!/usr/bin/env bash
#
# ============================================
# Purpose:           Verify the bundled typeface list matches across Swift, plists, and project.yml.
# When to use:       In CI, and after changing the set of bundled fonts.
# Safe to run in prod?  Yes — read-only validation, makes no writes.
# Owner:             Luke F. Walton
# ============================================
#
# Keeps the bundled typeface list aligned across Swift (LFWTypeface.bundledFileName),
# scripts/fetch_fonts.sh, WordOfTheDay/App/Info.plist, WordWidget/Info.plist, and
# project.yml (widget UIAppFonts). A mismatch can't be caught at compile time and
# would leave one target silently falling back to system fonts.
#
# Exits non-zero if any list disagrees.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_SWIFT="$ROOT/lfwdesignsystem/Sources/LFWDesignSystem/LFWTheme.swift"
FETCH_SCRIPT="$ROOT/scripts/fetch_fonts.sh"
APP_PLIST="$ROOT/WordOfTheDay/App/Info.plist"
WIDGET_PLIST="$ROOT/WordWidget/Info.plist"
PROJECT_YML="$ROOT/project.yml"

swift_fonts() {
  awk '/public var bundledFileName: String \{/,/^    \}/ {
    if (match($0, /return "/)) print $0
  }' "$THEME_SWIFT" \
    | sed -n 's/.*return "\([^"]*\.ttf\)".*/\1/p' \
    | sort
}

fetch_fonts() {
  grep -oE '"[^"]+\.ttf\|' "$FETCH_SCRIPT" | tr -d '"|' | sort
}

plist_fonts() {
  grep '\.ttf</string>' "$1" \
    | sed -n 's/.*<string>\([^<]*\.ttf\)<\/string>.*/\1/p' \
    | sort
}

yml_fonts() {
  awk '/UIAppFonts:/{in_block=1; next}
       in_block && /^[[:space:]]*-[[:space:]]*[^[:space:]]+\.ttf[[:space:]]*$/ {
         gsub(/^[[:space:]]*-[[:space:]]*/, ""); print; next
       }
       in_block && /^[^[:space:]]/ { in_block=0 }' "$PROJECT_YML" | sort
}

SWIFT_FONTS=()
while IFS= read -r line; do SWIFT_FONTS+=("$line"); done < <(swift_fonts)

FETCH_FONTS=()
while IFS= read -r line; do FETCH_FONTS+=("$line"); done < <(fetch_fonts)

APP_FONTS=()
while IFS= read -r line; do APP_FONTS+=("$line"); done < <(plist_fonts "$APP_PLIST")

WIDGET_FONTS=()
while IFS= read -r line; do WIDGET_FONTS+=("$line"); done < <(plist_fonts "$WIDGET_PLIST")

YML_FONTS=()
while IFS= read -r line; do YML_FONTS+=("$line"); done < <(yml_fonts)

if [[ ${#SWIFT_FONTS[@]} -eq 0 ]]; then
  echo "❌ No bundledFileName entries found in $THEME_SWIFT"
  exit 1
fi

compare_lists() {
  local label="$1"
  shift
  local -a other=("$@")
  if [[ ${#SWIFT_FONTS[@]} -ne ${#other[@]} ]]; then
    echo "❌ Font count mismatch: LFWTypeface has ${#SWIFT_FONTS[@]}, $label has ${#other[@]}"
    echo "   Swift : ${SWIFT_FONTS[*]}"
    echo "   $label: ${other[*]}"
    return 1
  fi
  local i
  for i in "${!SWIFT_FONTS[@]}"; do
    if [[ "${SWIFT_FONTS[$i]}" != "${other[$i]}" ]]; then
      echo "❌ Font list drift between LFWTypeface and $label:"
      echo "   Swift : ${SWIFT_FONTS[*]}"
      echo "   $label: ${other[*]}"
      return 1
    fi
  done
  return 0
}

failed=0
compare_lists "fetch_fonts.sh" "${FETCH_FONTS[@]}" || failed=1
compare_lists "WordOfTheDay/App/Info.plist" "${APP_FONTS[@]}" || failed=1
compare_lists "WordWidget/Info.plist" "${WIDGET_FONTS[@]}" || failed=1
compare_lists "project.yml (widget UIAppFonts)" "${YML_FONTS[@]}" || failed=1

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "✅ Bundled typefaces in sync (${#SWIFT_FONTS[@]} files): ${SWIFT_FONTS[*]}"
