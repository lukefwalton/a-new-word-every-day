#!/usr/bin/env bash
#
# sync_designsystem.sh — propagate the canonical LFWDesignSystem to the family.
#
# The design system is *vendored* (copied) into every app repo so each repo
# stays self-contained: clone it, build it, no external package resolution. The
# cost of that is drift. This script is the single source of truth: it treats
# THIS repo's `lfwdesignsystem/` as canonical and mirrors it byte-for-byte into
# the sibling app repos, then regenerates the CHECKSUMS manifest that each
# repo's CI drift guard (scripts/check_designsystem_sync.sh) verifies.
#
# Workflow: edit the design system HERE (a-new-word-every-day), bump
# lfwdesignsystem/VERSION, run this script, then commit each repo.
#
# Assumes the sibling repos are checked out next to this one:
#   <parent>/a-new-word-every-day   (canonical — this repo)
#   <parent>/workout-logger
#   <parent>/stop-political-texts
#   <parent>/interactive-music-ios
# Override the parent dir with SIBLINGS_DIR=/path/to/checkouts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANON_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANON_DS="$CANON_ROOT/lfwdesignsystem"
PARENT="${SIBLINGS_DIR:-$(cd "$CANON_ROOT/.." && pwd)}"

SIBLINGS=(workout-logger stop-political-texts interactive-music-ios)

# The parts of the package that MUST be byte-identical across every repo: the
# Swift code, the tests, the manifest, and the version stamp. LICENSE and
# README.md are deliberately excluded — each repo's copy names its own repository.
SYNC_ITEMS=(Sources Tests Package.swift VERSION)

# sha256 binary that works on both Linux (sha256sum) and macOS (shasum -a 256).
# Kept as a word-split string so `xargs $SHA_BIN` calls a real binary (xargs
# cannot invoke a shell function).
if command -v sha256sum >/dev/null 2>&1; then SHA_BIN="sha256sum"; else SHA_BIN="shasum -a 256"; fi

# Copy the synced items from canonical → dest, replacing each wholesale so
# deletions propagate. cp handles both files and directories; no rsync needed.
mirror() {
  local src="$1" dest="$2" item
  for item in "${SYNC_ITEMS[@]}"; do
    [ -e "$src/$item" ] || continue
    rm -rf "$dest/$item"
    cp -R "$src/$item" "$dest/$item"
  done
}

# Regenerate CHECKSUMS.txt for a given lfwdesignsystem dir: hash the synced items
# only, paths relative to the package root, sorted. Excludes LICENSE/README.
write_checksums() {
  local ds="$1"
  ( cd "$ds"
    find "${SYNC_ITEMS[@]}" -type f 2>/dev/null \
      | LC_ALL=C sort \
      | xargs $SHA_BIN > CHECKSUMS.txt
  )
}

echo "Canonical: $CANON_DS"
[ -d "$CANON_DS" ] || { echo "error: canonical lfwdesignsystem not found" >&2; exit 1; }

write_checksums "$CANON_DS"
echo "  regenerated canonical CHECKSUMS.txt (version $(cat "$CANON_DS/VERSION" 2>/dev/null || echo '?'))"

for name in "${SIBLINGS[@]}"; do
  dest="$PARENT/$name/lfwdesignsystem"
  if [ ! -d "$dest" ]; then
    echo "  skip  $name (no lfwdesignsystem at $dest)"
    continue
  fi
  # Mirror canonical → sibling so the copies stay identical; the manifest is
  # regenerated below so it never counts as a diff.
  mirror "$CANON_DS" "$dest"
  write_checksums "$dest"
  echo "  synced $name"
done

echo "Done. Review 'git status' in each repo, then commit."
