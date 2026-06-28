import SwiftUI
import UIKit
import LFWDesignSystem

/// The starred-words practice list, with a one-tap Anki export (native CSV, no
/// AGPL). Tapping a word focuses it on the Today tab.
struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var exportURL: ExportFile?

    private var typeface: LFWTypeface { model.theme.typeface }

    var body: some View {
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
                            exportURL = makeExport()
                        } label: {
                            Label("Export to Anki", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(item: $exportURL) { file in
                ShareSheet(url: file.url)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(model.starredWords) { word in
                Button {
                    model.focusedWordID = word.id
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(LFWTypography.font(.uiTitle, typeface: typeface, size: 20))
                        Text("\(word.partOfSpeechLabel) · \(word.definition)")
                            .font(LFWTypography.font(.uiBody, typeface: typeface, size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let ids = offsets.map { model.starredWords[$0].id }
                model.unstar(ids)
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No saved words", systemImage: "star")
        } description: {
            Text("Tap the star on a word to save it here for practice.")
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
