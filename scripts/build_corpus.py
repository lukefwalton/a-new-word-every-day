#!/usr/bin/env python3
"""Assemble the bundled corpora (words.json, words_ja.json, …) from source lists.

Purpose:           Validate scripts/corpus_source*.json and (re)generate the
                   bundled per-language corpus JSON.
When to use:       After editing a corpus source (add, remove, or reword entries).
Safe to run in prod?  Yes — deterministic; only rewrites the generated output.
Owner:             Luke F. Walton

The English corpus is original work: every word, definition, and difficulty band
in scripts/corpus_source.json was written for this app and is dedicated to the
public domain (CC0). The Japanese corpus's word list, kana readings, and
JLPT-level bands derive from Jonathan Waller's JLPT resources (tanos.co.uk,
CC-BY) via jamsinclair/open-anki-jlpt-decks (MIT); its definitions were written
for this app. Keep the in-app Acknowledgements in sync with this.

This script validates the source and assigns each word a **stable id derived
from the word itself** (a hash), not from its position. That matters because
persisted user state — starred words, difficulty marks — keys off `Word.id`, so
ids must never be reassigned when the list grows or is reordered. Adding,
removing, or re-sorting words leaves every other word's id untouched.
Non-English ids are salted with the language code ("ja:食べる") so the same
surface form in two languages can never collide; English ids stay unsalted,
byte-identical to every id ever shipped.

Usage:
    python scripts/build_corpus.py                # English
    python scripts/build_corpus.py --lang ja      # Japanese
"""

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

# Per-language config: source file, output file, allowed POS, allowed difficulty
# bands, whether entries carry a phonetic reading. Adding a language = one row
# here + a Language case in WordOfTheDay/Shared/Language.swift.
#
# `bands` must match that Language case's `levelNames` count. English runs 1..6
# (band 6, "Arcane", holds the words that are genuinely out of general
# circulation); Japanese stops at 5 because its bands *are* JLPT N5…N1 and there
# is no sixth JLPT level to name.
LANGUAGES = {
    "en": {
        "source": "corpus_source.json",
        "out": Path("WordOfTheDay/Resources/words.json"),
        "pos": {"n", "v", "adj", "adv"},
        "bands": {1, 2, 3, 4, 5, 6},
        "reading": False,
    },
    "ja": {
        "source": "corpus_source_ja.json",
        "out": Path("WordOfTheDay/Resources/words_ja.json"),
        "pos": {"n", "v", "adj", "adv", "expr"},
        "bands": {1, 2, 3, 4, 5},
        "reading": True,
    },
}


# Smallest band we'll ship. At one word a day a band this size still takes half
# a year to exhaust, and the reshuffle-per-cycle logic keeps the second pass from
# replaying the first.
MIN_BAND_SIZE = 150


def stable_id(word: str, lang: str) -> int:
    """A deterministic positive id that depends only on (language, word), so it
    never changes as a corpus is edited. English stays unsalted for backward
    compatibility with shipped user state. 52 bits keeps it well inside
    Swift's Int."""
    key = word if lang == "en" else f"{lang}:{word}"
    return int(hashlib.sha1(key.encode("utf-8")).hexdigest()[:13], 16)


def build(lang: str, source: Path, out: Path) -> list[dict]:
    cfg = LANGUAGES[lang]
    rows = json.loads(source.read_text(encoding="utf-8"))
    if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
        raise SystemExit(f"FAILED — {source.name} must be a JSON array of objects")
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
        if r.get("pos") not in cfg["pos"]:
            errors.append(f"{tag}: bad pos {r.get('pos')!r}")
        if not isinstance(r.get("band"), int) or isinstance(r.get("band"), bool) \
                or r.get("band") not in cfg["bands"]:
            errors.append(f"{tag}: band must be an integer 1..{max(cfg['bands'])}")
        if cfg["reading"]:
            if not isinstance(r.get("reading"), str) or not r["reading"].strip():
                errors.append(f"{tag}: reading must be a non-empty string")
        if r.get("word") in seen:
            errors.append(f"{tag}: duplicate word")
        seen.add(r.get("word"))
    # Selection is exact-band (DailySelector.eligible), so every band is a pool a
    # user can live in for months. A thin band would mean a fast repeat cycle,
    # and an empty one would trip the defensive whole-corpus fallback — which is
    # exactly the "hardest level serves easy words" bug this replaced.
    counts = Counter(r.get("band") for r in rows)
    missing = cfg["bands"] - set(counts)
    if missing:
        errors.append(f"every band {min(cfg['bands'])}..{max(cfg['bands'])} must be "
                      f"represented; missing {sorted(missing)}")
    thin = {b: n for b, n in counts.items() if b in cfg["bands"] and n < MIN_BAND_SIZE}
    if thin:
        errors.append(f"every band needs ≥{MIN_BAND_SIZE} words for a healthy "
                      f"selection pool; too thin: {dict(sorted(thin.items()))}")
    if errors:
        raise SystemExit(f"FAILED — fix {source.name}:\n" + "\n".join(errors))

    rows.sort(key=lambda r: (r["band"], r["word"]))
    out_rows = []
    for r in rows:
        entry = {"id": stable_id(r["word"], lang), "word": r["word"], "pos": r["pos"],
                 "definition": r["definition"], "band": r["band"]}
        if cfg["reading"] and r["reading"] != r["word"]:
            # Omit readings that just repeat the headword (kana-only words) —
            # Word.displayReading would hide them anyway, so don't ship the bytes.
            entry["reading"] = r["reading"]
        if lang != "en":
            # Every non-English entry carries its language tag (independent of
            # readings) — Word.language falls back to English when it's absent.
            entry["lang"] = lang
        out_rows.append(entry)
    ids = [r["id"] for r in out_rows]
    if len(set(ids)) != len(ids):
        dup = [w["word"] for w in out_rows if ids.count(w["id"]) > 1]
        raise SystemExit(f"FAILED — id hash collision between: {dup}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(out_rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"Wrote {len(out_rows)} words to {out}")
    print("Bands:", dict(sorted(Counter(r['band'] for r in out_rows).items())))
    print("POS:", dict(Counter(r['pos'] for r in out_rows)))
    return out_rows


def check_cross_language_collisions(lang: str, built_ids: set[int]):
    """Ids must be unique across every bundled corpus — starred/review state is
    one global id-keyed map. The per-language salt makes a collision all but
    impossible; this proves it for the actual data."""
    for other, cfg in LANGUAGES.items():
        if other == lang or not cfg["out"].exists():
            continue
        other_ids = {r["id"] for r in json.loads(cfg["out"].read_text(encoding="utf-8"))}
        clash = built_ids & other_ids
        if clash:
            raise SystemExit(f"FAILED — id collision with {cfg['out'].name}: {sorted(clash)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", choices=sorted(LANGUAGES), default="en")
    ap.add_argument("--source", type=Path, default=None)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    cfg = LANGUAGES[args.lang]
    source = args.source or Path(__file__).with_name(cfg["source"])
    out = args.out or cfg["out"]
    rows = build(args.lang, source, out)
    check_cross_language_collisions(args.lang, {r["id"] for r in rows})


if __name__ == "__main__":
    main()
