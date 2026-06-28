#!/usr/bin/env python3
"""Generate the bundled seed corpus: WordOfTheDay/Resources/words.json.

These ~100 elevated (GRE/SAT-tier) words ship with the app so it works on first
launch with zero network. The definitions and example sentences here are written
fresh for this project, so the seed carries **no third-party licensing
obligation** at all.

To scale to thousands of words later, use build_corpus.py instead, which sources
glosses from Princeton WordNet (permissive WordNet License) and difficulty bands
from Norvig's MIT-licensed frequency list. See docs/prior-art-and-licensing.md.

Schema per word:
    {"id": Int, "word": String, "pos": "n|v|adj|adv",
     "definition": String, "example": String, "band": 1...5}

`band` is difficulty: 1 = most accessible, 5 = rare/hardest. The app shows words
at or below the user's calibrated band (see DifficultyModel).
"""

import json
from pathlib import Path

# (word, pos, band, definition, example) — authored for this project.
WORDS = [
    # ---- Band 1: accessible but elevated ----
    ("candid", "adj", 1, "frank and honest in expression", "a candid assessment of her chances"),
    ("brisk", "adj", 1, "quick and energetic", "a brisk walk before breakfast"),
    ("vivid", "adj", 1, "strikingly bright or sharply detailed", "a vivid memory of the storm"),
    ("deter", "v", 1, "to discourage from acting through doubt or fear", "high fences deter trespassers"),
    ("blunt", "adj", 1, "so direct as to seem rude", "a blunt refusal"),
    ("quaint", "adj", 1, "attractively old-fashioned", "a quaint seaside village"),
    ("nimble", "adj", 1, "quick and light in movement or thought", "nimble fingers on the keys"),
    ("stark", "adj", 1, "severe or bare; sharply clear", "a stark contrast between them"),
    ("coax", "v", 1, "to gently persuade", "she coaxed the cat out from under the bed"),
    ("fret", "v", 1, "to worry persistently", "he fretted over the deadline"),
    ("jovial", "adj", 1, "cheerful and good-humored", "a jovial host"),
    ("meek", "adj", 1, "quiet, gentle, and submissive", "too meek to object"),
    ("sturdy", "adj", 1, "strongly and solidly built", "a sturdy oak table"),
    ("drab", "adj", 1, "dull and lacking color or interest", "a drab little office"),
    ("lush", "adj", 1, "growing thickly and abundantly", "lush green hillsides"),
    ("prod", "v", 1, "to prompt or urge into action", "prodded into apologizing"),
    ("hardy", "adj", 1, "able to endure difficult conditions", "a hardy alpine plant"),
    ("adapt", "v", 1, "to adjust to new conditions", "species adapt in order to survive"),
    ("mimic", "v", 1, "to imitate closely", "the parrot mimics human speech"),
    ("brittle", "adj", 1, "hard but easily broken", "the brittle old parchment"),

    # ---- Band 2 ----
    ("candor", "n", 2, "the quality of being open and honest", "I appreciated her candor"),
    ("prudent", "adj", 2, "acting with care and foresight", "a prudent investment"),
    ("placate", "v", 2, "to calm or soothe someone's anger", "he placated the angry customer"),
    ("frugal", "adj", 2, "sparing and economical with resources", "a frugal lifestyle"),
    ("lucid", "adj", 2, "clear and easy to understand; clear-minded", "a lucid explanation"),
    ("rampant", "adj", 2, "spreading unchecked", "rampant inflation"),
    ("tedious", "adj", 2, "tiresomely long or dull", "a tedious lecture"),
    ("wary", "adj", 2, "cautious of possible danger", "wary of strangers"),
    ("abstain", "v", 2, "to choose not to do something", "abstain from voting"),
    ("daunt", "v", 2, "to discourage or intimidate", "undaunted by the challenge"),
    ("fickle", "adj", 2, "changing frequently, especially in loyalty", "fickle public opinion"),
    ("mar", "v", 2, "to spoil or damage", "the scandal marred his reputation"),
    ("opaque", "adj", 2, "not transparent; hard to understand", "opaque legal jargon"),
    ("ponder", "v", 2, "to think about carefully", "she pondered the offer"),
    ("quell", "v", 2, "to suppress or put an end to", "troops quelled the riot"),
    ("rebuke", "v", 2, "to express sharp disapproval of", "rebuked for arriving late"),
    ("scoff", "v", 2, "to speak about dismissively or mockingly", "they scoffed at the idea"),
    ("sober", "adj", 2, "serious and solemn; not intoxicated", "a sober warning"),
    ("concede", "v", 2, "to admit or yield", "he conceded the point"),
    ("novel", "adj", 2, "new and original", "a novel approach to the problem"),

    # ---- Band 3 ----
    ("austere", "adj", 3, "severe or plain; strict in self-discipline", "an austere monastic life"),
    ("belie", "v", 3, "to give a false impression of; contradict", "her calm voice belied her fear"),
    ("cogent", "adj", 3, "clear, logical, and convincing", "a cogent argument"),
    ("deference", "n", 3, "respectful submission to another's judgment", "in deference to her elders"),
    ("ephemeral", "adj", 3, "lasting a very short time", "ephemeral internet fame"),
    ("garrulous", "adj", 3, "excessively talkative", "a garrulous old neighbor"),
    ("impede", "v", 3, "to obstruct or delay", "fallen debris impeded the rescue"),
    ("laconic", "adj", 3, "using very few words", "a laconic reply of 'fine'"),
    ("mitigate", "v", 3, "to make less severe", "measures to mitigate the damage"),
    ("nuance", "n", 3, "a subtle difference in meaning or tone", "the nuances of the language"),
    ("ostensible", "adj", 3, "apparent but not necessarily genuine", "the ostensible reason for his visit"),
    ("placid", "adj", 3, "calm and peaceful", "a placid mountain lake"),
    ("prosaic", "adj", 3, "dull and ordinary", "a prosaic explanation"),
    ("rancor", "n", 3, "bitter, long-lasting resentment", "she spoke without rancor"),
    ("spurious", "adj", 3, "false despite appearing genuine", "a spurious claim of authority"),
    ("tenuous", "adj", 3, "very weak or slight", "a tenuous connection to the case"),
    ("venerate", "v", 3, "to regard with deep respect", "venerated as a national hero"),
    ("wane", "v", 3, "to decrease in size or intensity", "his enthusiasm soon waned"),
    ("zealous", "adj", 3, "having great energy or passion", "a zealous reformer"),
    ("cordial", "adj", 3, "warm and friendly", "a cordial welcome"),

    # ---- Band 4 ----
    ("abrogate", "v", 4, "to formally abolish or repeal", "to abrogate a treaty"),
    ("capricious", "adj", 4, "given to sudden changes of mood", "a capricious ruler"),
    ("diffident", "adj", 4, "shy and lacking self-confidence", "a diffident newcomer"),
    ("ebullient", "adj", 4, "cheerful and full of energy", "an ebullient host"),
    ("fastidious", "adj", 4, "attentive to detail; hard to please", "a fastidious editor"),
    ("gregarious", "adj", 4, "sociable; fond of company", "a gregarious personality"),
    ("iconoclast", "n", 4, "one who attacks cherished beliefs or institutions", "a political iconoclast"),
    ("inchoate", "adj", 4, "just begun and not fully formed", "an inchoate plan"),
    ("munificent", "adj", 4, "extremely generous", "a munificent donation"),
    ("obfuscate", "v", 4, "to deliberately make unclear", "to obfuscate the truth"),
    ("pernicious", "adj", 4, "harmful in a gradual, subtle way", "a pernicious habit"),
    ("quixotic", "adj", 4, "idealistic and impractical", "a quixotic crusade"),
    ("recalcitrant", "adj", 4, "stubbornly resistant to authority", "a recalcitrant student"),
    ("sanguine", "adj", 4, "optimistic, especially in a hard situation", "sanguine about the outcome"),
    ("surfeit", "n", 4, "an excessive amount", "a surfeit of information"),
    ("taciturn", "adj", 4, "reserved; saying little", "a taciturn farmer"),
    ("truculent", "adj", 4, "eager to argue or fight", "a truculent reply"),
    ("ubiquitous", "adj", 4, "present everywhere", "ubiquitous smartphones"),
    ("vacillate", "v", 4, "to waver between choices", "to vacillate over a decision"),
    ("wanton", "adj", 4, "deliberate and unprovoked; reckless", "wanton destruction"),

    # ---- Band 5: rare / hardest ----
    ("abstruse", "adj", 5, "difficult to understand; obscure", "abstruse mathematics"),
    ("captious", "adj", 5, "tending to raise petty objections", "a captious critic"),
    ("desultory", "adj", 5, "lacking a plan or purpose; random", "a desultory conversation"),
    ("ersatz", "adj", 5, "being an inferior substitute", "ersatz coffee made from acorns"),
    ("fulsome", "adj", 5, "excessive and insincere, especially of praise", "fulsome flattery"),
    ("grandiloquent", "adj", 5, "pompous or extravagant in language", "a grandiloquent speech"),
    ("hegemony", "n", 5, "leadership or dominance, especially by one state", "regional hegemony"),
    ("inveigle", "v", 5, "to persuade by deception or flattery", "he inveigled his way in"),
    ("jejune", "adj", 5, "naive and simplistic; dull", "jejune political slogans"),
    ("lugubrious", "adj", 5, "looking or sounding mournful", "a lugubrious expression"),
    ("mendacious", "adj", 5, "untruthful; lying", "a mendacious witness"),
    ("nugatory", "adj", 5, "of little or no value", "a nugatory sum"),
    ("obstreperous", "adj", 5, "noisy and difficult to control", "obstreperous children"),
    ("pellucid", "adj", 5, "transparently clear in style or meaning", "pellucid prose"),
    ("quotidian", "adj", 5, "ordinary; everyday", "the quotidian routines of life"),
    ("recondite", "adj", 5, "little known; dealing with obscure subjects", "recondite scholarship"),
    ("sycophant", "n", 5, "a person who flatters to gain advantage", "surrounded by sycophants"),
    ("turgid", "adj", 5, "pompous and tediously overblown; swollen", "turgid academic prose"),
    ("vituperative", "adj", 5, "bitter and abusive", "a vituperative attack"),
    ("perfidious", "adj", 5, "deceitful and untrustworthy", "a perfidious ally"),
]

VALID_POS = {"n", "v", "adj", "adv"}


def build():
    seen = set()
    out = []
    for i, (word, pos, band, definition, example) in enumerate(WORDS, start=1):
        assert pos in VALID_POS, f"bad pos for {word!r}: {pos}"
        assert 1 <= band <= 5, f"bad band for {word!r}: {band}"
        assert word not in seen, f"duplicate word: {word}"
        seen.add(word)
        out.append({
            "id": i,
            "word": word,
            "pos": pos,
            "definition": definition,
            "example": example,
            "band": band,
        })
    return out


def main():
    out = build()
    dest = Path(__file__).resolve().parent.parent / "WordOfTheDay" / "Resources" / "words.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    bands = {b: sum(1 for w in out if w["band"] == b) for b in range(1, 6)}
    print(f"Wrote {len(out)} words to {dest}")
    print(f"Per band: {bands}")


if __name__ == "__main__":
    main()
