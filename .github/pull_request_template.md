## What & why

<!-- What does this change do, and why? Link any related issue (e.g. Closes #12). -->

## Checklist

- [ ] CI passes (iOS tests + config/corpus guardrails)
- [ ] Tests added or updated for new logic, where it applies
- [ ] Corpus change?
  - **English:** edited `scripts/corpus_source.json`, ran `python3 scripts/build_corpus.py` (didn't hand-edit `words.json`)
  - **Japanese:** edited `scripts/corpus_source_ja.json`, ran `python3 scripts/build_corpus.py --lang ja` (didn't hand-edit `words_ja.json`; Tanos CC BY attribution preserved — see [NOTICE](NOTICE))
- [ ] Docs updated if behavior or setup changed
