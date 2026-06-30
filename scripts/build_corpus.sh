#!/usr/bin/env bash
#
# ============================================
# Purpose:           Regenerate WordOfTheDay/Resources/words.json from the CC0 corpus source.
# When to use:       After editing scripts/corpus_source.json.
# Safe to run in prod?  Yes — deterministic; only rewrites the generated words.json.
# Owner:             Luke F. Walton
# ============================================
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/build_corpus.py "$@"
