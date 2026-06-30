#!/usr/bin/env bash
# Build, seed demo state, and capture App Store screenshots in the simulator.
#
# Output: build/app-store-screenshots/
#   iphone/   6.5" (1284×2778) — required for iPhone
#   ipad/     13"  (2064×2752) — required even for iPhone-only apps on iPad
#
# Requires: Xcode, iOS Simulator, fonts (scripts/fetch_fonts.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f project.local.yml ]; then
  bash scripts/generate.sh
else
  xcodegen generate
fi

if ! compgen -G "WordOfTheDay/Resources/Fonts/*.ttf" > /dev/null 2>&1; then
  bash scripts/fetch_fonts.sh
fi

pick_sim() {
  python3 - "$@" <<'PY'
import json, subprocess, sys
names = sys.argv[1:]
out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
devices = json.loads(out)["devices"]
for want in names:
    for devs in devices.values():
        for d in devs:
            if d.get("isAvailable") and d["name"] == want:
                print(d["udid"])
                raise SystemExit
for want in names:
    for devs in devices.values():
        for d in devs:
            if d.get("isAvailable") and want in d["name"]:
                print(d["udid"])
                raise SystemExit
raise SystemExit(f"No simulator found for: {names}")
PY
}

BUNDLE="com.lukewalton.wordoftheday"
BASE_ARGS=(-UITestResetOnboarding -UITestSkipOnboarding -ScreenshotDemo)

flatten_png() {
  local src="$1" dest="$2" w="$3" h="$4"
  local tmp="${dest%.png}.jpg"
  sips -s format jpeg -s formatOptions 100 "$src" --out "$tmp" >/dev/null
  sips -s format png "$tmp" --out "$dest" >/dev/null
  rm -f "$tmp"
  sips -z "$h" "$w" "$dest" --out "$dest" >/dev/null
}

capture_set() {
  local sim_id="$1" out_dir="$2" w="$3" h="$4" label="$5"
  mkdir -p "$out_dir"

  echo ""
  echo "=== $label (${w}x${h}) — $sim_id ==="
  echo "Building for simulator..."
  xcodebuild build \
    -scheme WordOfTheDay \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$sim_id" \
    -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO >/dev/null

  local app="build/DerivedData/Build/Products/Debug-iphonesimulator/WordOfTheDay.app"
  xcrun simctl boot "$sim_id" 2>/dev/null || true
  open -a Simulator --args -CurrentDeviceUDID "$sim_id"
  sleep 2
  xcrun simctl uninstall "$sim_id" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$sim_id" "$app"

  capture_one() {
    local slug="$1"
    shift
    echo "→ $slug"
    xcrun simctl terminate "$sim_id" "$BUNDLE" 2>/dev/null || true
    sleep 0.4
    xcrun simctl launch "$sim_id" "$BUNDLE" -- "${BASE_ARGS[@]}" "$@"
    sleep 3.5
    local raw="/tmp/anwed-${label}-${slug}-raw.png"
    xcrun simctl io "$sim_id" screenshot "$raw"
    flatten_png "$raw" "$out_dir/${slug}.png" "$w" "$h"
    rm -f "$raw"
    echo "  ✓ $out_dir/${slug}.png"
  }

  capture_one "01-today"
  capture_one "02-settings" -OpenTabSettings
  capture_one "03-practice" -OpenTabPractice
}

IPHONE_SIM="${IPHONE_SIM:-$(pick_sim "iPhone 15 Pro Max" "iPhone 14 Plus" "iPhone 15 Plus" "iPhone 16 Plus")}"
IPAD_SIM="${IPAD_SIM:-$(pick_sim "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)" "iPad Pro 12.9-inch (6th generation)")}"

capture_set "$IPHONE_SIM" "build/app-store-screenshots/iphone" 1284 2778 "iPhone 6.5\""
capture_set "$IPAD_SIM"   "build/app-store-screenshots/ipad"   2064 2752 "iPad 13\""

echo ""
echo "Done."
echo "  iPhone → build/app-store-screenshots/iphone/"
echo "  iPad   → build/app-store-screenshots/ipad/"
open build/app-store-screenshots
