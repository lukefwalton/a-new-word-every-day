import SwiftUI
import LFWDesignSystem

/// Typeface + color theming, difficulty, and an honest About section. Writes
/// every change through `AppModel` so the widget updates too.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ThemedScreen(theme: model.theme) {
            NavigationStack {
                Form {
                    typefaceSection
                    colorSection
                    difficultySection
                    aboutSection
                }
                .modifier(ThemedFormChrome(palette: palette))
                .foregroundStyle(palette.primaryText)
                .navigationTitle("Settings")
            }
        }
    }

    // MARK: Typeface

    private var typefaceSection: some View {
        Section("Typeface") {
            ForEach(LFWTypeface.allCases) { face in
                Button {
                    var theme = model.theme
                    theme.typeface = face
                    model.setTheme(theme)
                } label: {
                    HStack {
                        Text("Eloquent")
                            .font(LFWTypography.font(.uiTitle, typeface: face, size: 22))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Text(face.displayName)
                            .foregroundStyle(palette.secondaryText)
                        if face == typeface {
                            Image(systemName: "checkmark").foregroundStyle(palette.accent)
                        }
                    }
                }
                .tint(palette.accent)
            }
        }
    }

    // MARK: Color

    private var colorSection: some View {
        Section("Color") {
            ForEach(LFWPalette.allCases) { paletteOption in
                Button {
                    var theme = model.theme
                    theme.palette = paletteOption
                    model.setTheme(theme)
                } label: {
                    HStack(spacing: 12) {
                        swatch(paletteOption)
                        Text(paletteOption.displayName).foregroundStyle(palette.primaryText)
                        Spacer()
                        if paletteOption == model.theme.palette {
                            Image(systemName: "checkmark").foregroundStyle(palette.accent)
                        }
                    }
                }
                .tint(palette.accent)
            }

            VStack(alignment: .leading) {
                Text("Accent hue")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                Slider(
                    value: Binding(
                        get: { model.theme.accentHueShift },
                        set: { newValue in
                            var theme = model.theme
                            theme.accentHueShift = newValue
                            model.setTheme(theme, reloadWidget: false)
                        }
                    ),
                    in: -180...180, step: 5,
                    onEditingChanged: { editing in
                        if !editing { model.reloadWidget() }
                    }
                )
                .tint(palette.accent)
            }
        }
    }

    private func swatch(_ paletteOption: LFWPalette) -> some View {
        let c = paletteOption.colors
        return RoundedRectangle(cornerRadius: LFWRadius.chip, style: .continuous)
            .fill(LinearGradient(colors: [c.backgroundTop, c.backgroundBottom],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 28)
            .overlay(Circle().fill(c.accent).frame(width: 10, height: 10).padding(5),
                     alignment: .bottomTrailing)
            .overlay(RoundedRectangle(cornerRadius: LFWRadius.chip)
                .strokeBorder(.black.opacity(0.1)))
    }

    // MARK: Difficulty

    private var difficultySection: some View {
        Section {
            Stepper(value: Binding(get: { model.band }, set: { model.setBand($0) }), in: 1...5) {
                HStack {
                    Text("Difficulty")
                    Spacer()
                    Text(bandLabel(model.band)).foregroundStyle(palette.secondaryText)
                }
            }
            .tint(palette.accent)
        } footer: {
            Text("Higher levels surface rarer words. Marking words as known or still-learning nudges this automatically.")
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func bandLabel(_ band: Int) -> String {
        ["", "Gentle", "Easy", "Medium", "Hard", "Rare"][min(max(band, 0), 5)]
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            Label("Free. No account, no tracking, no analytics.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
            DisclosureGroup("Acknowledgements") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The word list and its definitions were written for this app and are dedicated to the public domain (CC0) — free for anyone to use.")
                    Text("Typefaces — Fraunces, Literata, Inter, Recursive — are licensed under the SIL Open Font License 1.1.")
                    Text("Review scheduling uses FSRS via swift-fsrs, licensed under the MIT License. It runs entirely on-device.")
                }
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
            }
            .tint(palette.accent)
        }
    }
}
