import SwiftUI
import LFWDesignSystem

/// Typeface + color theming, difficulty, and an honest About section. Writes
/// every change through `AppModel` so the widget updates too.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var typeface: LFWTypeface { model.theme.typeface }

    var body: some View {
        NavigationStack {
            Form {
                typefaceSection
                colorSection
                difficultySection
                aboutSection
            }
            .navigationTitle("Settings")
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
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(face.displayName)
                            .foregroundStyle(.secondary)
                        if face == typeface {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(model.theme.colors.accent)
            }
        }
    }

    // MARK: Color

    private var colorSection: some View {
        Section("Color") {
            ForEach(LFWPalette.allCases) { palette in
                Button {
                    var theme = model.theme
                    theme.palette = palette
                    model.setTheme(theme)
                } label: {
                    HStack(spacing: 12) {
                        swatch(palette)
                        Text(palette.displayName).foregroundStyle(.primary)
                        Spacer()
                        if palette == model.theme.palette {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(model.theme.colors.accent)
            }

            VStack(alignment: .leading) {
                Text("Accent hue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { model.theme.accentHueShift },
                        set: { newValue in
                            var theme = model.theme
                            theme.accentHueShift = newValue
                            model.setTheme(theme)
                        }
                    ),
                    in: -180...180, step: 5
                )
                .tint(model.theme.colors.accent)
            }
        }
    }

    private func swatch(_ palette: LFWPalette) -> some View {
        let c = palette.colors
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
                    Text(bandLabel(model.band)).foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Higher levels surface rarer words. Marking words as known or still-learning nudges this automatically.")
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
            DisclosureGroup("Acknowledgements") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Definitions in the larger word list derive from Princeton WordNet (WordNet License).")
                    Text("Word difficulty uses Peter Norvig's frequency data (MIT).")
                    Text("Typefaces — Fraunces, Literata, Inter, Recursive — are licensed under the SIL Open Font License 1.1.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
