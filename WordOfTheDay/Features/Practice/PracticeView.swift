import SwiftUI
import UIKit
import LFWDesignSystem

/// The starred-words practice list, with a one-tap Anki export (native CSV, no
/// AGPL). Tapping a word focuses it on the Today tab.
struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var exportURL: ExportFile?
    @State private var exportFailed = false

    private var typeface: LFWTypeface { model.theme.typeface }
    private var palette: LFWPaletteColors { model.theme.colors }

    var body: some View {
        ThemedScreen(theme: model.theme) {
            NavigationStack {
                Group {
                    if model.starredWords.isEmpty {
                        empty
                    } else {
                        list
                    }
                }
                .navigationTitle("Practice")
                .toolbar {
                    if !model.starredWords.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                if let file = makeExport() {
                                    exportURL = file
                                } else {
                                    exportFailed = true
                                }
                            } label: {
                                Label("Export to Anki", systemImage: "square.and.arrow.up")
                            }
                            .tint(palette.accent)
                        }
                    }
                }
                .sheet(item: $exportURL) { file in
                    ShareSheet(url: file.url)
                }
                .alert("Couldn't create the export file", isPresented: $exportFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Something went wrong writing the file. Please try again.")
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(model.starredWords) { word in
                Button {
                    model.openWord(word.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 20))
                            .foregroundStyle(palette.primaryText)
                        Text("\(word.partOfSpeechLabel) · \(word.definition)")
                            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 14))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .tint(palette.primaryText)
            }
            .onDelete { offsets in
                let ids = offsets.map { model.starredWords[$0].id }
                model.unstar(ids)
            }
        }
        .modifier(ThemedListChrome(palette: palette))
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No saved words", systemImage: "star")
                .foregroundStyle(palette.primaryText)
        } description: {
            Text("Tap the star on a word to save it here for practice.")
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func makeExport() -> ExportFile? {
        let tsv = AnkiExporter.tsv(for: model.starredWords)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("word-of-the-day-anki.txt")
        do {
            try tsv.write(to: url, atomically: true, encoding: .utf8)
            return ExportFile(url: url)
        } catch {
            return nil
        }
    }
}

/// Identifiable wrapper so the share sheet binds to a value.
private struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// Minimal UIActivityViewController bridge (SwiftUI's ShareLink can't share an
/// arbitrary on-disk file with a custom UTI as cleanly across iOS versions).
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
