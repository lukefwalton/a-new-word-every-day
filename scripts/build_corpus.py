#!/usr/bin/env python3
"""Assemble WordOfTheDay/Resources/words.json from the hand-authored corpus.

The corpus is original work: every word, definition, and difficulty band in
scripts/corpus_source.json was written for this app and is dedicated to the
public domain (CC0). There is **no** external data dependency — no frequency
list, no third-party dictionary, no scraped text — so the shipped word list is
free for anyone to use without attribution or share-alike obligations.

This script just validates the source and gives it stable ids: it sorts by
(band, word) and numbers the entries 1..N. Run it after editing the source.

Usage:
    python scripts/build_corpus.py
    python scripts/build_corpus.py --out WordOfTheDay/Resources/words.json
"""

import argparse
import json
from collections import Counter
from pathlib import Path

VALID_POS = {"n", "v", "adj", "adv"}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source", type=Path,
                    default=Path(__file__).with_name("corpus_source.json"))
    ap.add_argument("--out", type=Path,
                    default=Path("WordOfTheDay/Resources/words.json"))
    args = ap.parse_args()

    rows = json.loads(args.source.read_text())
    if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
        raise SystemExit(f"FAILED — {args.source.name} must be a JSON array of objects")
    errors = []
    seen = set()
    for i, r in enumerate(rows):
        tag = r.get("word", f"#{i}")
        # Type-strict so a hand-edit typo (e.g. "definition": 123) fails here
        # rather than at runtime when Swift's Codable Word fails to decode.
        if not isinstance(r.get("word"), str) or not r["word"].strip():
            errors.append(f"{tag}: word must be a non-empty string")
        if not isinstance(r.get("definition"), str) or not r["definition"].strip():
            errors.append(f"{tag}: definition must be a non-empty string")
        if r.get("pos") not in VALID_POS:
            errors.append(f"{tag}: bad pos {r.get('pos')!r}")
        if not isinstance(r.get("band"), int) or isinstance(r.get("band"), bool) \
                or r.get("band") not in (1, 2, 3, 4, 5):
            errors.append(f"{tag}: band must be an integer 1..5")
        if r.get("word") in seen:
            errors.append(f"{tag}: duplicate word")
        seen.add(r.get("word"))
    bands = {r.get("band") for r in rows}
    if bands != {1, 2, 3, 4, 5}:
        errors.append(f"every band 1..5 must be represented; got {sorted(bands)}")
    if errors:
        raise SystemExit("FAILED — fix corpus_source.json:\n" + "\n".join(errors))

    rows.sort(key=lambda r: (r["band"], r["word"]))
    out = [{"id": i, "word": r["word"], "pos": r["pos"],
            "definition": r["definition"], "band": r["band"]}
           for i, r in enumerate(rows, start=1)]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")

    print(f"Wrote {len(out)} words to {args.out}")
    print("Bands:", dict(sorted(Counter(r['band'] for r in out).items())))
    print("POS:", dict(Counter(r['pos'] for r in out)))


if __name__ == "__main__":
    main()
