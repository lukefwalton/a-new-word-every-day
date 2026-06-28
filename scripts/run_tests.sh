#!/usr/bin/env bash
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

DEST='platform=iOS Simulator,name=iPhone 15'
if ! xcrun simctl list devices available | grep -q "iPhone 15 ("; then
  UDID=$(xcrun simctl list devices available --json \
    | python3 -c "import json,sys; r=json.load(sys.stdin)['devices']; ids=[d['udid'] for ds in r.values() for d in ds if d['name'].startswith('iPhone') and d['isAvailable']]; print(ids[0] if ids else '')")
  if [ -z "$UDID" ]; then
    echo "No iPhone simulator found" >&2
    exit 1
  fi
  DEST="platform=iOS Simulator,id=$UDID"
fi

xcodebuild test \
  -scheme WordOfTheDay \
  -destination "$DEST" \
  CODE_SIGNING_ALLOWED=NO
