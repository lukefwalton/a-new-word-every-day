# LFWDesignSystem

A tiny SwiftUI design system, vendored into this repo — shared visual language
across Luke F. Walton's iOS apps so onboarding and chrome feel like a family.

It ships:

- **Palette** — `LFWColors.{ocean, deepSea, gold, paper, ink, traveler, nebula, kelp, steel}`
- **Metrics** — `LFWRadius.{chip, card, surface}`
- **Onboarding kit** — `LFWOnboardingScaffold`, `LFWHeroIcon`,
  `LFWOnboardingMessage`, `LFWFeatureRow`, `LFWPageDots`
- **Background** — `LFWOnboardingBackground` (the shared moving-blob layer)
- **Buttons** — `LFWCTAButtonStyle` / `.buttonStyle(.lfwCTA)`
- **Variable fonts** — `Font.lfwVariable(_:size:axes:)` + `LFWVariableFont` axis
  tags and `.lfwVariableAxis(...)` for animating an axis (used by Word of the Day
  for the configurable hero type). Core Text under the hood; SwiftUI has no
  first-class axis API.
- **Typography** — `LFWTypography.font(_:typeface:)` resolves semantic
  `LFWTextRole`s to a chosen `LFWTypeface`, falling back to a system face when the
  OFL font isn't bundled.
- **Theming** — `LFWThemeConfig` (typeface + `LFWPalette` + accent-hue nudge),
  Codable so the app and widget read one shared choice; `LFWThemedBackground`.

The app consumes it as a local Swift Package via XcodeGen (`packages:` →
`path: lfwdesignsystem`) and `dependencies: [{ package: LFWDesignSystem }]`.
It's resolved by relative path; because this is a vendored copy of the shared
package, keep it in sync if you maintain multiple apps that use it.

Copyright Luke F. Walton — see [LICENSE](LICENSE) (same terms as the app).

## Family rule of thumb

If a screen exists to *welcome*, *explain*, or *gate* the user (onboarding,
empty states, permission walls), reach for these components — that's where
family resemblance pays off most. App-specific gameplay surfaces (a HUD over
a camera, a workout log row, a Form-based settings page) can still use
domain-specific styling; they just shouldn't pull the family apart at the
front door.
