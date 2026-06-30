#!/usr/bin/env bash
#
# ============================================
# Purpose:           Generate the project and run the Swift unit suite on a simulator.
# When to use:       Before pushing, and to reproduce CI locally.
# Safe to run in prod?  Yes — builds and tests only; no release side effects.
# Owner:             Luke F. Walton
# ============================================
set -euo pipefail
cd "$(dirname "$0")/.."

# Generate the same project you build locally: if project.local.yml exists, go
# through the merge flow (team/bundle overrides) rather than a bare xcodegen,
# so tests run against the same generated project as `scripts/generate.sh`.
if [ -f project.local.yml ]; then
  bash scripts/generate.sh
else
  xcodegen generate
fi

# Variable fonts are gitignored; fetch before building if absent.
if ! compgen -G "WordOfTheDay/Resources/Fonts/*.ttf" > /dev/null; then
  bash scripts/fetch_fonts.sh
fi

# xcodebuild's `name=iPhone 15` destination uses OS:latest, which often fails
# when multiple runtimes expose the same device name. Always pin a UDID instead.
DEST=$(python3 <<'PY'
import json, subprocess

def pick():
    out = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True
    )
    devices = json.loads(out)["devices"]
    iphones = []
    for runtime, devs in devices.items():
        for d in devs:
            if d.get("isAvailable") and d["name"].startswith("iPhone"):
                iphones.append(d)
    if not iphones:
        return None
    for preferred in ("iPhone 15", "iPhone 16", "iPhone 17"):
        for d in iphones:
            if d["name"] == preferred:
                return d["udid"]
    return iphones[0]["udid"]

udid = pick()
if not udid:
    raise SystemExit("No iPhone simulator found")
print(f"platform=iOS Simulator,id={udid}")
PY
)

xcodebuild test \
  -scheme WordOfTheDay \
  -destination "$DEST" \
  CODE_SIGNING_ALLOWED=NO
