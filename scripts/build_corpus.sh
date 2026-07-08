#!/usr/bin/env bash
#
# ============================================
# Purpose:           Regenerate a bundled corpus (words.json / words_ja.json) from its source.
# When to use:       After editing scripts/corpus_source.json (or corpus_source_ja.json; pass --lang ja).
# Safe to run in prod?  Yes — deterministic; only rewrites the generated output.
# Owner:             Luke F. Walton
# ============================================
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/build_corpus.py "$@"
