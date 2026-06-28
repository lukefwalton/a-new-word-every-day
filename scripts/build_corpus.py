#!/usr/bin/env python3
"""Scale the corpus from ~100 seed words to thousands — permissively.

This is the *optional* scale path. The app ships with the curated seed produced
by seed_corpus.py; run this only when you want a larger corpus. It assembles
every field from permissive / public-domain sources, so the output stays freely
redistributable (see docs/prior-art-and-licensing.md):

  * Definitions + part of speech + examples -> Princeton WordNet
        (WordNet License: OSI-approved, BSD/MIT-style, attribution only).
  * Difficulty bands -> Peter Norvig's count_1w.txt frequency list (MIT).
        Rarer word => higher band.
  * Headword selection -> WordNet lemmas intersected with a GRE/SAT-tier
        frequency window (rank ~8k-60k) so we keep "elevated" words and drop
        both the trivially common and the vanishingly rare.

Explicitly NOT used (share-alike / GPL / unclear): Wiktionary, dictionaryapi.dev,
Wordset, GCIDE, wordfreq/SUBTLEX bundled data, scraped commercial GRE lists.

Requirements (install yourself; intentionally not vendored):
    pip install nltk
    python -c "import nltk; nltk.download('wordnet'); nltk.download('omw-1.4')"
    # Norvig frequency list:
    curl -O https://norvig.com/ngrams/count_1w.txt

Usage:
    python scripts/build_corpus.py --freq count_1w.txt --max-words 2000 \
        --out WordOfTheDay/Resources/words.json

The attribution this requires (WordNet + Norvig MIT) is already carried in
NOTICE and the in-app Acknowledgements screen — keep it there if you scale up.
"""

import argparse
import json
import sys
from pathlib import Path

POS_MAP = {"n": "n", "v": "v", "a": "adj", "s": "adj", "r": "adv"}  # WordNet POS -> ours


def load_frequency_ranks(path: Path) -> dict[str, int]:
    """word -> rank (1 = most frequent). count_1w.txt is 'word<TAB>count', desc."""
    ranks: dict[str, int] = {}
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        parts = line.split()
        if parts:
            ranks.setdefault(parts[0].lower(), i)
    return ranks


def band_for_rank(rank: int) -> int:
    """Map a frequency rank to a 1..5 difficulty band (rarer => higher)."""
    # Tuned so the GRE/SAT-tier window (~8k..60k) spreads across bands 1..5.
    thresholds = [12000, 20000, 32000, 50000]  # < => bands 1,2,3,4 ; else 5
    for band, t in enumerate(thresholds, start=1):
        if rank < t:
            return band
    return 5


def build(freq_path: Path, max_words: int) -> list[dict]:
    try:
        from nltk.corpus import wordnet as wn
    except ImportError:
        sys.exit("nltk not installed. See the header of this file for setup.")

    ranks = load_frequency_ranks(freq_path)
    chosen: dict[str, dict] = {}

    # Walk WordNet lemmas; keep those inside the elevated frequency window.
    for syn in wn.all_synsets():
        pos = POS_MAP.get(syn.pos())
        if pos is None:
            continue
        for lemma in syn.lemma_names():
            word = lemma.lower()
            if "_" in word or not word.isalpha() or len(word) < 3:
                continue
            rank = ranks.get(word)
            if rank is None or rank < 8000 or rank > 60000:
                continue  # too common or too obscure for "elevated"
            if word in chosen:
                continue
            definition = syn.definition()
            examples = syn.examples()
            chosen[word] = {
                "word": word,
                "pos": pos,
                "definition": definition,
                "example": examples[0] if examples else "",
                "band": band_for_rank(rank),
                "_rank": rank,
            }

    # Prefer the rarer (more interesting) words up to the cap, then re-id.
    ordered = sorted(chosen.values(), key=lambda w: w["_rank"], reverse=True)[:max_words]
    ordered.sort(key=lambda w: w["_rank"])  # final order: easier first
    out = []
    for i, w in enumerate(ordered, start=1):
        w.pop("_rank", None)
        out.append({"id": i, **w})
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--freq", required=True, type=Path, help="Norvig count_1w.txt")
    ap.add_argument("--max-words", type=int, default=2000)
    ap.add_argument("--out", type=Path,
                    default=Path("WordOfTheDay/Resources/words.json"))
    args = ap.parse_args()

    out = build(args.freq, args.max_words)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(out)} words to {args.out}")
    print("Remember: WordNet + Norvig attribution must stay in NOTICE / Acknowledgements.")


if __name__ == "__main__":
    main()
