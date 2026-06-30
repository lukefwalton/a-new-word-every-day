# Security Policy

A New Word Every Day is a local-first iOS app. It has **no backend, no accounts,
and makes no network calls at runtime** — all data (starred words, difficulty,
theme, review schedules) stays on device in an App Group store the app and its
widget share. That removes whole classes of vulnerability: there's no server to
breach, no data in transit, and no third-party data processor. The app, the
widget's interactive star intent, and the build/release scripts can still have
bugs worth reporting privately.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Instead:

1. Email **[luke@lukefwalton.com](mailto:luke@lukefwalton.com)** with a
   description of the issue.
2. Include steps to reproduce, the affected area (app, widget, or a script), and
   the potential impact.
3. You'll get an acknowledgement within a few days. Please allow a reasonable
   window to ship a fix before disclosing publicly.

## In scope

- On-device data exposure through the shared App Group store or the widget
- Any path that causes the app to make an unexpected network request
- Issues in the build/release scripts (`scripts/`) that could compromise a
  release archive or leak signing material
- Supply-chain concerns (the app links only the vendored `lfwdesignsystem`
  package and bundles OFL fonts fetched by `scripts/fetch_fonts.sh`)

## Not a security issue

- Feature requests, visual/UI bugs, or crashes with no security impact — please
  use [GitHub Issues](https://github.com/lukefwalton/a-new-word-every-day/issues).

## Supported versions

Fixes target the latest App Store release and the `main` branch. Older builds are
not separately patched.
