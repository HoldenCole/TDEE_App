import XCTest
@testable import TareFiles

final class CSVTests: XCTestCase {

    func testSimpleParse() {
        let t = CSV.parse("a,b,c\n1,2,3\n4,5,6\n")
        XCTAssertEqual(t.columns, ["a", "b", "c"])
        XCTAssertEqual(t.rows, [["1", "2", "3"], ["4", "5", "6"]])
    }

    func testQuotedFieldsWithCommasNewlinesAndQuotes() {
        let text = "name,note\r\n\"Smith, John\",\"said \"\"hi\"\"\r\nthen left\"\r\nplain,\"\"\r\n"
        let t = CSV.parse(text)
        XCTAssertEqual(t.columns, ["name", "note"])
        XCTAssertEqual(t.rows.count, 2)
        XCTAssertEqual(t.rows[0][0], "Smith, John")
        XCTAssertEqual(t.rows[0][1], "said \"hi\"\nthen left")
        XCTAssertEqual(t.rows[1], ["plain", ""])
    }

    func testBOMAndCRLFAndRaggedRows() {
        let text = "\u{FEFF}date,weight,kcal\r\n2026-10-13,184.6\r\n2026-10-14,183.9,2600,extra\r\n"
        let t = CSV.parse(text)
        XCTAssertEqual(t.columns, ["date", "weight", "kcal"])
        XCTAssertEqual(t.rows[0], ["2026-10-13", "184.6", ""])
        XCTAssertEqual(t.rows[1], ["2026-10-14", "183.9", "2600"])
    }

    func testDelimiterDetection() {
        let semi = CSV.parse("a;b;c\n1;2,5;3\n")
        XCTAssertEqual(semi.columns, ["a", "b", "c"])
        XCTAssertEqual(semi.rows[0], ["1", "2,5", "3"])
        let tab = CSV.parse("a\tb\n1\t2\n")
        XCTAssertEqual(tab.columns, ["a", "b"])
        XCTAssertEqual(tab.rows[0], ["1", "2"])
        let forced = CSV.parse("a|b\n1|2\n", delimiter: "|")
        XCTAssertEqual(forced.columns, ["a", "b"])
    }

    func testBlankLinesSkippedAndNoTrailingNewline() {
        let t = CSV.parse("a,b\n\n1,2\n\n3,4")
        XCTAssertEqual(t.rows, [["1", "2"], ["3", "4"]])
        XCTAssertEqual(CSV.parse("").columns, [])
    }

    func testWriteQuotesProperly() {
        let t = Table(columns: ["a", "b"], rows: [["x,y", "say \"hi\""], ["line\nbreak", " padded "]])
        let out = CSV.write(t, lineEnding: "\n")
        XCTAssertEqual(out, "a,b\n\"x,y\",\"say \"\"hi\"\"\"\n\"line\nbreak\",\" padded \"\n")
        let back = CSV.parse(out)
        XCTAssertEqual(back, t)
    }
}
