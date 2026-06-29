#!/usr/bin/env python3
"""Build a ~1000-word "elevated everyday" corpus from the long tail of modern
English usage.

The idea (per the project owner): take a frequency distribution of *common
modern English* and pick from its long tail — words that are genuinely used and
recognizable, but sit below the trivially-common head. Each field is then filled
from a real source, never invented:

  * Headword selection + difficulty bands -> `wordfreq` (modern multi-source
        English frequencies). We walk the Zipf long tail, keep only real
        dictionary headwords, and split the result into five difficulty bands by
        frequency quintile (rarer => higher band).
  * Definition + part of speech -> Princeton WordNet. The dominant POS comes
        from Brown Corpus tags (fixing WordNet's noun-bias); a small curated
        scripts/sense_overrides.json pins the right sense for ambiguous words
        whose WordNet default is the wrong homograph (hacker -> the programmer,
        not the bad golfer). scripts/sense_golden.json snapshots those so CI
        fails if a sense regresses.
  * Example sentence -> a real sentence in which the word (or an inflection)
        appears, preferring, in order:
            1. a curated supplement (examples_supplement.json) for modern words
               our public-domain corpora don't cover,
            2. a WordNet example that uses the word,
            3. a Project Gutenberg sentence (public-domain literature),
            4. a Brown Corpus sentence (1960s American English),
            5. any WordNet example for the chosen sense.

LICENSING (read docs/prior-art-and-licensing.md before shipping):
  Because the *selection and banding* derive from wordfreq's data — part of
  which is Creative Commons Attribution-ShareAlike 4.0 — the generated
  words.json is distributed under CC-BY-SA 4.0 (share-alike), unlike the rest of
  the MIT-licensed app. Attribution for wordfreq, WordNet, Project Gutenberg and
  the Brown Corpus is carried in NOTICE and the in-app Acknowledgements.

Setup (install yourself; intentionally not vendored):
    pip install nltk wordfreq
    python -c "import nltk; [nltk.download(p) for p in \
        ('wordnet','omw-1.4','gutenberg','brown','punkt','punkt_tab', \
         'averaged_perceptron_tagger','averaged_perceptron_tagger_eng')]"

Usage:
    python scripts/build_modern_corpus.py \
        --out WordOfTheDay/Resources/words.json --count 1000
"""

import argparse
import json
import re
from collections import Counter
from pathlib import Path

POS_MAP = {"n": "n", "v": "v", "a": "adj", "s": "adj", "r": "adv"}

# Frequency window (Zipf) for the "elevated long tail": recognizable but not
# trivially common. Words are taken from the filtered candidate list between
# these ranks (after the common head is skipped).
POOL_START, POOL_END = 2600, 9600

# Words we never want as headwords: function words, light/common verbs, deixis,
# chatty filler, plus a few that survive the WordNet filter but read poorly.
STOP = set(
    """the a an and or but if then else when while of to in on at by for with from into onto upon
about above below under over again once here there all any both each few more most other some such no
nor not only own same so than too very can will just don should now is are was were be been being have
has had do does did this that these those it its he she they them his her their you your we our us me my
mine i am as up down out off who whom whose which what why how also yet still ever never always lets
let get got make made take took give gave go went come came see saw know knew think thought say said
tell told put set lay want shall would could may might must one two three four five six seven eight
nine ten man men woman day time year way thing things people good great little long old new first last
much many even back today yeah okay yep yup lot lots gonna wanna kinda sorta etc via per stuff guy guys
really right work years before life world through best love home look need follow round save whatever
amount drive eat dream luck touch wave usual theme tiny finish grand sweet skin rich thus mil sup doc
gig kitty psycho daddy mommy momma mum mummy doll nope dude pal""".split()
)

# Greek letters, Roman numerals, clippings/abbreviations, and lowercase
# homographs of proper nouns that WordNet still lists as common lemmas.
GREEK = set("phi chi psi eta rho tau iota zeta theta kappa sigma upsilon omicron epsilon gamma".split())
ROMAN = set("ii iii iv vi vii viii ix xi xii xiii xiv xv xvi xvii xviii xix xx xxi".split())
CLIPPED = set("maths telecom prep deco cos sec prob promo combo limo condo expo info demo "
              "amino aqua pong mack rep admin uni macro mono aba roc ling spec specs ref "
              "dumbass atm var meg".split())
PROPERISH = set("ruth easter costa silva tesla marcel ulster burgess leone ira romana amelia "
                "veronica davenport beth dyer bailey warner somerset coco dixie medina mina "
                "colleen ness berg rutherford benedict lambert toby gemma argentine milo "
                "erica amir kraft butch cisco skinner langley breakers kylie brent phoebe "
                "blah".split())
# Comparatives/superlatives WordNet still lists as standalone lemmas.
INFLECTED = set("healthier".split())
# Words whose WordNet most-frequent sense is the wrong/obscure one for a modern
# reader (e.g. tuna -> "prickly pear", roach -> "roll of hair") or is a slur.
MISSENSE = set("taco tuna sticker roach bot mei lulu veg midterm metabolism punctuation "
               "interactive hooker shite doggy sweetie obi".split())
# Crude/explicit terms we keep out of a word-of-the-day surface.
PROFANE = set("asshole ass crap damn dick shit fuck fucking bitch piss bastard slut whore cunt "
              "screw blowjob incest masturbation penis fart fucker rapist pedophile dildo "
              "faggot pervert fag dyke".split())
BLOCK = STOP | GREEK | ROMAN | CLIPPED | PROPERISH | INFLECTED | MISSENSE | PROFANE

# Removed *after* selection and swapped for the next clean pool candidate. Use
# this — not BLOCK — to weed out stragglers spotted in a finished list: editing
# BLOCK shifts the whole even-subsample and orphans the example supplement,
# whereas a post-selection swap leaves all other picks untouched. (Mostly brand
# names, clippings, and proper-noun homographs that read wrong as a daily word.)
DROP_AFTER = set("chevy collins franklin morocco murphy nelson sierra pol grad lite horny "
                 "marc chapman phoenix whale kite".split())


_LEMMA_CACHE = {}


def token_lemmas(wn, token):
    """Every WordNet base form of a surface token, plus the token itself.

    Example mining matches a sentence to a headword by *lemma*: `walked` lemmatizes
    to `walk` (a hit), but `board` lemmatizes only to `board` — never to `boar` —
    so suffix collisions like boar/board or shin/shining can't sneak through.
    """
    tl = token.lower()
    cached = _LEMMA_CACHE.get(tl)
    if cached is not None:
        return cached
    lemmas = {tl}
    if tl.isalpha():
        for p in ("n", "v", "a", "r"):
            m = wn.morphy(tl, p)
            if m:
                lemmas.add(m)
    _LEMMA_CACHE[tl] = lemmas
    return lemmas


def clean_definition(d: str) -> str:
    d = re.sub(r"\s+", " ", d).strip()
    # Drop a leading usage qualifier like "(used of ...)" or "(plural)".
    d = re.sub(r"^\((?:used|usually|especially|chiefly|often|plural|sometimes|now|"
               r"archaic|formal|informal|slang)[^)]*\)\s*", "", d, flags=re.I)
    d = re.sub(r"^\([^)]{0,28}\)\s*", "", d)
    if len(d) > 96:
        cut = d[:96]
        for sep in (";", "--", ", "):
            i = cut.rfind(sep)
            if i > 50:
                cut = cut[:i]
                break
        d = cut.rstrip(" ,;-")
    return (d[0].lower() + d[1:]) if d else d


_POS_ORDER = {"n": 0, "v": 1, "a": 2, "r": 3}
_WN_POS = {"n": "n", "v": "v", "a": "a", "s": "a", "r": "r"}  # WordNet pos -> our 4


def brown_dominant_pos(brown):
    """word (lowercased) -> its most common part of speech in the Brown Corpus,
    mapped to {n, v, a, r}. Empirical modern usage, used to choose a word's
    sense when WordNet has no frequency signal."""
    tag_to_pos = {"NN": "n", "VB": "v", "JJ": "a", "RB": "r"}
    counts = {}
    for word, tag in brown.tagged_words():
        wl = word.lower()
        if not wl.isalpha():
            continue
        pos = tag_to_pos.get(tag[:2])
        if pos:
            counts.setdefault(wl, {})
            counts[wl][pos] = counts[wl].get(pos, 0) + 1
    return {wl: max(c, key=c.get) for wl, c in counts.items()}


def best_synset(wn, word, dominant_pos=None, override=None):
    """Pick the word's most useful sense: its dominant part of speech, then the
    most-frequent sense within it (preferring one that ships an example).

    The dominant POS comes from real usage in the Brown Corpus when available,
    which fixes WordNet's noun-bias on words that have no SemCor counts — so
    `conserve` and `import` come out as verbs and `facial` as an adjective,
    instead of defaulting to the noun homograph. Falls back to SemCor counts,
    then WordNet's POS order. Lemmas are matched case-sensitively so proper nouns
    (capitalized in WordNet) are skipped.

    `override` (a WordNet synset name like "aviation.n.02") forces a specific
    sense for ambiguous words where WordNet's own ordering and SemCor counts pick
    a meaning that isn't the common modern one (aviation -> military aircraft,
    realise -> "earn cash"). Words whose every sense is wrong are dropped via
    MISSENSE.
    """
    if override:
        syn = wn.synset(override)
        assert any(l.name() == word for l in syn.lemmas()), \
            f"override {override} has no lemma {word!r}"
        return syn
    syns = [s for s in wn.synsets(word) if any(l.name() == word for l in s.lemmas())]
    if not syns:
        return None
    available = {_WN_POS[s.pos()] for s in syns}

    best_pos = dominant_pos if (dominant_pos in available) else None
    if best_pos is None:
        pos_count = {}
        for s in syns:
            for l in s.lemmas():
                if l.name() == word:
                    p = _WN_POS[s.pos()]
                    pos_count[p] = pos_count.get(p, 0) + l.count()
        best_pos = max(pos_count, key=lambda p: (pos_count[p], -_POS_ORDER.get(p, 9)))

    def lemma_count(s):
        return max(l.count() for l in s.lemmas() if l.name() == word)

    cands = [s for s in syns if _WN_POS[s.pos()] == best_pos]
    cands.sort(key=lambda s: (-lemma_count(s), 0 if s.examples() else 1))
    return cands[0]


def reducible(wn, word) -> bool:
    """True if the word is an inflected form (so we keep only base headwords)."""
    for p in ("n", "v", "a", "r"):
        m = wn.morphy(word, p)
        if m and m != word:
            return True
    return False


def detokenize(det, sent):
    return det.detokenize(sent)


_OUR_TO_WN = {"n": "n", "v": "v", "adj": "a", "adv": "r"}


def coarse_pos(penn_tag):
    """Penn Treebank tag -> our {n, v, adj, adv}, or None. Proper-noun tags
    (NNP/NNPS) are deliberately excluded so a token like `Fiat` can't match the
    common noun `fiat`."""
    if penn_tag in ("NN", "NNS"):
        return "n"
    if penn_tag.startswith("VB"):
        return "v"
    if penn_tag.startswith("JJ"):
        return "adj"
    if penn_tag.startswith("RB"):
        return "adv"
    return None


def build_corpus_index(corpus, word_pos, wn, nltk, det, lo=5, hi=22, maxlen=118):
    """word -> shortest clean sentence (from `corpus`) that uses it *in its part
    of speech*.

    Matching is lemma- and POS-aware on two levels: a token must reduce to the
    headword under the headword's own POS (so `dived`/`hacked` can't match the
    nouns `dive`/`hack`), and the token must actually be tagged as that POS in
    the sentence (so the bare verb `dive` in "dive deep" can't match the noun
    either). Homograph collisions like boar/board never match at all.
    """
    by_pos = {"n": set(), "v": set(), "adj": set(), "adv": set()}
    for w, p in word_pos.items():
        by_pos[p].add(w)
    best = {}
    for sent in corpus.sents():
        n = len(sent)
        if n < lo or n > hi:
            continue
        # Candidate (headword, surface token, pos) hits by lemma under each POS.
        cand = []
        for t in sent:
            tl = t.lower()
            if not tl.isalpha():
                continue
            for our_pos, wn_pos in _OUR_TO_WN.items():
                pool = by_pos[our_pos]
                if not pool:
                    continue
                base = tl if tl in pool else wn.morphy(tl, wn_pos)
                if base in pool:
                    cand.append((base, tl, our_pos))
        if not cand:
            continue
        # Confirm each candidate token is actually tagged as that POS here.
        tok_tags = {}
        for tok, tag in nltk.pos_tag(sent):
            tok_tags.setdefault(tok.lower(), set()).add(coarse_pos(tag))
        hits = {base for base, tl, our_pos in cand if our_pos in tok_tags.get(tl, ())}
        if not hits:
            continue
        txt = detokenize(det, sent)
        if any(c in txt for c in '"_[]*|/<>') or not re.match(r"^[A-Z]", txt):
            continue
        if len(txt) > maxlen or txt.count("(") != txt.count(")"):
            continue
        txt = re.sub(r"\s+", " ", txt).strip().rstrip(";").strip()
        for w in hits:
            if w not in best or len(txt) < len(best[w]):
                best[w] = txt
    return best


def example_uses_word(wn, sentence, word):
    """True if `word` appears in `sentence` as a headword or inflection (by lemma)."""
    return any(word in token_lemmas(wn, t) for t in re.findall(r"[A-Za-z']+", sentence))


def wn_example_with_word(wn, syn, word):
    for ex in syn.examples():
        if example_uses_word(wn, ex, word):
            return ex
    return None


def main():
    import nltk
    import wordfreq as wf
    from nltk.corpus import gutenberg, brown, wordnet as wn
    from nltk.tokenize.treebank import TreebankWordDetokenizer

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=Path("WordOfTheDay/Resources/words.json"))
    ap.add_argument("--count", type=int, default=1000)
    ap.add_argument("--supplement", type=Path,
                    default=Path(__file__).with_name("examples_supplement.json"))
    ap.add_argument("--sense-overrides", type=Path,
                    default=Path(__file__).with_name("sense_overrides.json"))
    args = ap.parse_args()

    det = TreebankWordDetokenizer()
    supplement = {}
    if args.supplement.exists():
        supplement = json.loads(args.supplement.read_text())
    sense_overrides = {}
    if args.sense_overrides.exists():
        sense_overrides = json.loads(args.sense_overrides.read_text())

    # Empirical dominant part of speech per word, from the Brown Corpus tags.
    dom_pos = brown_dominant_pos(brown)

    # 1. Filtered candidate list, in descending modern-frequency order.
    candidates = []
    for w in wf.top_n_list("en", 80000):
        if not (w.isascii() and w.isalpha()) or len(w) < 3:
            continue
        if w in BLOCK or reducible(wn, w):
            continue
        s = best_synset(wn, w, dom_pos.get(w), sense_overrides.get(w))
        if s is None:
            continue
        candidates.append((w, wf.zipf_frequency(w, "en"), s))

    # 2. Subsample `count` words evenly across the long-tail window so the five
    #    difficulty bands span a real range of frequencies.
    #    NOTE: this even-subsample is sensitive to the candidate list — changing
    #    BLOCK or the window shifts *which* words are picked, which can orphan
    #    entries in examples_supplement.json. After any such change, re-run and
    #    re-fill the supplement for whatever the run reports as still missing.
    pool = candidates[POOL_START:POOL_END]
    step = len(pool) / float(args.count)
    selected = [pool[int(i * step)] for i in range(args.count)]

    # Swap out post-selection rejects for the next unused, clean pool candidate,
    # so the rest of the picks (and their authored examples) stay put.
    chosen = {w for w, _, _ in selected}
    spare = (c for c in pool if c[0] not in chosen and c[0] not in DROP_AFTER)
    for i, (w, _z, _s) in enumerate(selected):
        if w in DROP_AFTER:
            repl = next(spare)
            chosen.add(repl[0])
            selected[i] = repl
    word_pos = {w: POS_MAP[s.pos()] for w, _, s in selected}

    # 3. Example indices over the public-domain / redistributable corpora.
    gut = build_corpus_index(gutenberg, word_pos, wn, nltk, det, lo=5, hi=22)
    brn = build_corpus_index(brown, word_pos, wn, nltk, det, lo=5, hi=24)

    # 4. Assemble. Band by frequency quintile (rarer => higher band).
    selected.sort(key=lambda x: -x[1])
    rows = []
    src = Counter()
    for idx, (w, _z, s) in enumerate(selected):
        band = min(5, idx * 5 // args.count + 1)
        pos = POS_MAP[s.pos()]
        if w in supplement:
            ex, tag = supplement[w], "supplement"
        elif (e := wn_example_with_word(wn, s, w)):
            ex, tag = e, "wordnet"
        elif w in gut:
            ex, tag = gut[w], "gutenberg"
        elif w in brn:
            ex, tag = brn[w], "brown"
        elif s.examples():
            ex, tag = s.examples()[0], "wordnet"
        else:
            ex, tag = "", "MISSING"
        src[tag] += 1
        ex = re.sub(r"\s+", " ", ex).strip()
        if len(ex) > 140:
            ex = ex[:137].rsplit(" ", 1)[0] + "…"
        rows.append({"word": w, "pos": pos, "definition": clean_definition(s.definition()),
                     "example": ex, "band": band})

    rows.sort(key=lambda r: (r["band"], r["word"]))
    out = [{"id": i, **r} for i, r in enumerate(rows, start=1)]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")

    print(f"Wrote {len(out)} words to {args.out}")
    print("Example sources:", dict(src))
    print("Bands:", dict(sorted(Counter(r['band'] for r in out).items())))
    print("POS:", dict(Counter(r['pos'] for r in out)))
    if src.get("MISSING"):
        missing = [r["word"] for r in rows if not r["example"]]
        print(f"\n{len(missing)} words still need an example — add them to "
              f"{args.supplement.name}:\n" + "\n".join(missing))

    # Guard: every example must actually use its headword (lemma-aware). Catches
    # bad supplement entries and any future matching regression.
    mismatched = [r["word"] for r in out
                  if r["example"] and not example_uses_word(wn, r["example"], r["word"])]
    if mismatched:
        print(f"\nWARNING: {len(mismatched)} examples do not contain their headword: "
              + ", ".join(mismatched))


if __name__ == "__main__":
    main()
