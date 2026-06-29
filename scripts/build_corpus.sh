#!/usr/bin/env bash
# Regenerate words.json from the CC0 corpus source.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/build_corpus.py "$@"
