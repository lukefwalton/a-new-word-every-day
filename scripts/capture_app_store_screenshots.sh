#!/usr/bin/env bash
# Build, seed demo state, and capture 6.5" App Store screenshots in the simulator.
#
# Output: build/app-store-screenshots/
#   01-today.png      — hero word (Today tab)
#   02-settings.png   — widget preview + customization (Settings)
#   03-practice.png   — starred words list (Practice)
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

SIM_ID="${SIM_ID:-$(python3 <<'PY'
import json, subprocess
out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
devices = json.loads(out)["devices"]
candidates = []
for runtime, devs in devices.items():
    for d in devs:
        if d.get("isAvailable") and d["name"] in (
            "iPhone 14 Plus", "iPhone 15 Plus", "iPhone 15 Pro Max", "iPhone 16 Plus"
        ):
            candidates.append(d)
for preferred in ("iPhone 15 Pro Max", "iPhone 14 Plus", "iPhone 15 Plus", "iPhone 16 Plus"):
    for d in candidates:
        if d["name"] == preferred:
            print(d["udid"])
            raise SystemExit
if candidates:
    print(candidates[0]["udid"])
else:
    raise SystemExit("No 6.5\" iPhone simulator found (need iPhone 14 Plus class)")
PY
)}"

BUNDLE="com.lukewalton.wordoftheday"
OUT_DIR="build/app-store-screenshots"
mkdir -p "$OUT_DIR"

echo "Building for simulator ($SIM_ID)..."
xcodebuild build \
  -scheme WordOfTheDay \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO >/dev/null

APP="build/DerivedData/Build/Products/Debug-iphonesimulator/WordOfTheDay.app"

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_ID"
sleep 2

xcrun simctl uninstall "$SIM_ID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$SIM_ID" "$APP"

BASE_ARGS=(-UITestResetOnboarding -UITestSkipOnboarding -ScreenshotDemo)

flatten_png() {
  local src="$1" dest="$2"
  local tmp="${dest%.png}.jpg"
  sips -s format jpeg -s formatOptions 100 "$src" --out "$tmp" >/dev/null
  sips -s format png "$tmp" --out "$dest" >/dev/null
  rm -f "$tmp"
  sips -z 2778 1284 "$dest" --out "$dest" >/dev/null
}

capture() {
  local slug="$1"
  shift
  echo "→ $slug"
  xcrun simctl terminate "$SIM_ID" "$BUNDLE" 2>/dev/null || true
  sleep 0.4
  xcrun simctl launch "$SIM_ID" "$BUNDLE" -- "${BASE_ARGS[@]}" "$@"
  sleep 3.5
  local raw="/tmp/anwed-${slug}-raw.png"
  xcrun simctl io "$SIM_ID" screenshot "$raw"
  flatten_png "$raw" "$OUT_DIR/${slug}.png"
  rm -f "$raw"
  W=$(sips -g pixelWidth "$OUT_DIR/${slug}.png" | awk '/pixelWidth/{print $2}')
  H=$(sips -g pixelHeight "$OUT_DIR/${slug}.png" | awk '/pixelHeight/{print $2}')
  echo "  ✓ $OUT_DIR/${slug}.png (${W}×${H})"
}

capture "01-today"
capture "02-settings" -OpenTabSettings
capture "03-practice" -OpenTabPractice

echo ""
echo "Done → $OUT_DIR/"
ls -la "$OUT_DIR"/*.png
open "$OUT_DIR"
