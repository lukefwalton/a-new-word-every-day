# Contributing

Thanks for your interest in **A New Word Every Day** — a free, local-first iOS
word-of-the-day app and widget. Contributions are welcome, whether that's a new
word for the corpus, a bug fix, or a docs improvement.

By participating you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Suggest a word** — the most useful contribution. Open a
  [word suggestion issue](https://github.com/lukefwalton/a-new-word-every-day/issues/new/choose)
  or edit the corpus directly (see below).
- **Fix a bug or improve a feature** — for anything non-trivial, open an issue
  first so we can agree on the approach before you build it.
- **Improve the docs** — all documentation lives in [`docs/`](docs/) and is
  linked from the [README](README.md).

## Development setup

See [Build](README.md#build) in the README. In short:

```bash
brew install xcodegen
python3 -m pip install pyyaml
cp project.local.yml.example project.local.yml   # set DEVELOPMENT_TEAM
bash scripts/generate.sh
open WordOfTheDay.xcodeproj
```

## Editing the word corpus

The corpus is **hand-authored and public-domain (CC0)**. Don't edit
`WordOfTheDay/Resources/words.json` directly — it's generated. Instead:

1. Edit [`scripts/corpus_source.json`](scripts/corpus_source.json). Each entry is
   `{ "word", "pos", "definition", "band" }`, where `pos` is one of
   `n` / `v` / `adj` / `adv` and `band` is a difficulty from 1 (most accessible)
   to 5 (rarest). Definitions must be **original** — no copied dictionary text.
2. Regenerate: `bash scripts/build_corpus.sh`
3. Commit both files. CI re-runs the build and fails if `words.json` is out of
   date with its source.

## Tests

```bash
bash scripts/run_tests.sh
```

The deterministic core — daily selection, difficulty calibration, store,
exporter, scheduler, corpus integrity — is covered by `WordOfTheDayTests`. Please
keep the suite green and add tests for new logic.

## Pull requests

- Branch off `main`, keep the change focused, and open a PR.
- Match the style of the surrounding code; an [`.editorconfig`](.editorconfig)
  covers the basics (LF endings, four-space Swift/Python indentation, trimmed
  whitespace).
- Make sure CI passes — both the iOS test suite and the config/corpus guardrails.
- Describe what changed and why.

## Licensing of contributions

By contributing you agree that your contributions are licensed under this repo's
terms: **code under [MIT](LICENSE)**, and **word-list entries dedicated to the
public domain under [CC0](NOTICE)**. Don't submit content you don't have the
right to release this way.

## Security

Found a vulnerability? Please don't open a public issue — see
[SECURITY.md](SECURITY.md).
