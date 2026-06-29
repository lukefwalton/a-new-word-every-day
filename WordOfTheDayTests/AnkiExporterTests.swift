import XCTest
@testable import WordOfTheDay

final class AnkiExporterTests: XCTestCase {

    func test_headers_makeImportTurnkey() {
        let tsv = AnkiExporter.tsv(for: [Fixtures.word(1, band: 1)])
        XCTAssertTrue(tsv.contains("#separator:tab"))
        XCTAssertTrue(tsv.contains("#notetype:Basic"))
        XCTAssertTrue(tsv.contains("#deck:Word of the Day"))
        XCTAssertTrue(tsv.contains("#tags:wordoftheday starred"))
        XCTAssertTrue(tsv.contains("#columns:Front\tBack"))
    }

    func test_row_hasFrontTabBack() {
        let word = Word(id: 1, word: "laconic", pos: "adj",
                        definition: "using very few words", band: 3)
        let tsv = AnkiExporter.tsv(for: [word])
        let row = tsv.split(separator: "\n").first { $0.hasPrefix("laconic") }
        XCTAssertNotNil(row)
        let cols = row!.split(separator: "\t")
        XCTAssertEqual(cols.count, 2)
        XCTAssertEqual(cols[0], "laconic")
        XCTAssertTrue(cols[1].contains("(adjective)"))
        XCTAssertTrue(cols[1].contains("using very few words"))
    }

    func test_lineCount_isHeadersPlusWords() {
        let words = (1...5).map { Fixtures.word($0, band: 1) }
        let lines = AnkiExporter.tsv(for: words).split(separator: "\n")
        XCTAssertEqual(lines.count, 6 + 5) // 6 header directives + 5 rows
    }

    func test_tabsInContentAreSanitized() {
        let word = Word(id: 1, word: "x", pos: "n",
                        definition: "a\tb\nc", band: 1)
        let tsv = AnkiExporter.tsv(for: [word])
        let row = tsv.split(separator: "\n").first { $0.hasPrefix("x\t") }!
        // Exactly one tab (the column separator) in the row.
        XCTAssertEqual(row.filter { $0 == "\t" }.count, 1)
        XCTAssertFalse(row.contains("\n"))
    }
}
