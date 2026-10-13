import XCTest
@testable import TareFiles

final class XLSXTests: XCTestCase {

    func testWriteReadRoundTripWithNumbersAndSanitizedName() throws {
        let table = Table(columns: ["date", "weight_lb", "note", "code"], rows: [
            ["2026-10-13", "184.6", "a & b <c>", "007"],
            ["2026-10-14", "2650", "", "x"],
            ["2026-10-15", "-3.25", "  spaced  ", "1e3"],
        ])
        let wb = Workbook(sheets: [
            Sheet(name: "Days", table: table),
            Sheet(name: "Lifts: [2026]/*bad?name\\that is far too long for excel", table: Table(columns: ["x"], rows: [["1"]])),
        ])
        let data = try XLSX.write(wb)
        XCTAssertGreaterThan(data.count, 500)

        let back = try XLSX.read(data)
        XCTAssertEqual(back.sheets.count, 2)
        XCTAssertEqual(back.sheets[0].name, "Days")
        XCTAssertEqual(back.sheets[1].name, "Lifts- -2026---bad-name-that is")
        XCTAssertEqual(back.sheets[1].name.count, 31)
        XCTAssertEqual(back.sheets[0].table.columns, table.columns)
        XCTAssertEqual(back.sheets[0].table.rows[0], ["2026-10-13", "184.6", "a & b <c>", "007"])
        XCTAssertEqual(back.sheets[0].table.rows[1], ["2026-10-14", "2650", "", "x"])
        XCTAssertEqual(back.sheets[0].table.rows[2], ["2026-10-15", "-3.25", "  spaced  ", "1000"])
    }

    func testSheetXMLUsesNumericAndInlineStringCells() {
        let xml = XLSX.sheetXML(Table(columns: ["n", "s"], rows: [["12.5", "hello"]]))
        XCTAssertTrue(xml.contains("<c r=\"A2\"><v>12.5</v></c>"))
        XCTAssertTrue(xml.contains("<c r=\"B2\" t=\"inlineStr\"><is><t>hello</t></is></c>"))
        XCTAssertTrue(xml.contains("<c r=\"A1\" t=\"inlineStr\" s=\"1\"><is><t>n</t></is></c>"))
    }

    func testColumnLetters() {
        XCTAssertEqual(XLSX.columnLetters(0), "A")
        XCTAssertEqual(XLSX.columnLetters(25), "Z")
        XCTAssertEqual(XLSX.columnLetters(26), "AA")
        XCTAssertEqual(XLSX.columnLetters(701), "ZZ")
        XCTAssertEqual(XLSX.columnLetters(702), "AAA")
        XCTAssertEqual(XLSX.columnIndex("A1"), 0)
        XCTAssertEqual(XLSX.columnIndex("AA10"), 26)
        XCTAssertEqual(XLSX.columnIndex("ZZ"), 701)
    }

    func testSerialDates() {
        XCTAssertEqual(XLSX.dateString(fromSerial: 46308), "2026-10-13")
        XCTAssertEqual(XLSX.dateString(fromSerial: 46308.5, withTime: true), "2026-10-13 12:00:00")
        XCTAssertEqual(XLSX.dateString(fromSerial: 1), "1900-01-01")
        XCTAssertEqual(XLSX.dateString(fromSerial: 61), "1900-03-01")
        XCTAssertEqual(XLSX.dateString(fromSerial: 0, date1904: true), "1904-01-01")
    }

    /// A hand-built workbook: shared strings with rich-text runs, a date-styled serial, a
    /// custom date format, booleans, cells without `r`, and gaps between columns.
    func testReadsSharedStringsDateStylesBooleansAndSparseCells() throws {
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>
        """
        let rels = """
        <?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """
        let workbook = """
        <?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Second" sheetId="2" r:id="rIdB"/><sheet name="First" sheetId="1" r:id="rIdA"/></sheets></workbook>
        """
        let wbRels = """
        <?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdA" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rIdB" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet2.xml"/><Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>
        """
        let shared = """
        <?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3"><si><t>date</t></si><si><r><rPr><b/></rPr><t>Bench </t></r><r><t>Press</t></r></si><si><t xml:space="preserve">done </t></si></sst>
        """
        let styles = """
        <?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/><numFmt numFmtId="165" formatCode="#,##0.00"/></numFmts><cellXfs count="4"><xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="164"/><xf numFmtId="165"/></cellXfs></styleSheet>
        """
        let sheet1 = """
        <?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="D1" t="inlineStr"><is><t>flag</t></is></c><c r="E1" t="inlineStr"><is><t>amount</t></is></c><c r="F1" t="inlineStr"><is><t>custom</t></is></c></row>
        <row r="2"><c r="A2" s="1"><v>46308</v></c><c r="D2" t="b"><v>1</v></c><c r="E2" s="3"><v>1234.5</v></c><c r="F2" s="2"><v>46309</v></c></row>
        <row><c t="s"><v>2</v></c><c><v>184.59999999999999</v></c><c r="D3" t="b"><v>0</v></c></row>
        </sheetData></worksheet>
        """
        let sheet2 = """
        <?xml version="1.0" encoding="UTF-8"?><x:worksheet xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><x:sheetData><x:row r="1"><x:c r="A1" t="inlineStr"><x:is><x:t>only</x:t></x:is></x:c></x:row><x:row r="2"><x:c r="A2"><x:v>7</x:v></x:c></x:row></x:sheetData></x:worksheet>
        """
        let data = try Zip.archive([
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("xl/workbook.xml", Data(workbook.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(wbRels.utf8)),
            ("xl/sharedStrings.xml", Data(shared.utf8)),
            ("xl/styles.xml", Data(styles.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheet1.utf8)),
            ("xl/worksheets/sheet2.xml", Data(sheet2.utf8)),
        ])
        let wb = try XLSX.read(data)
        XCTAssertEqual(wb.sheets.map(\.name), ["Second", "First"])
        XCTAssertEqual(wb.sheets[0].table.columns, ["only"])
        XCTAssertEqual(wb.sheets[0].table.rows, [["7"]])

        let first = wb.sheets[1].table
        XCTAssertEqual(first.columns, ["date", "Bench Press", "", "flag", "amount", "custom"])
        XCTAssertEqual(first.rows.count, 2)
        XCTAssertEqual(first.rows[0], ["2026-10-13", "", "", "true", "1234.5", "2026-10-14"])
        XCTAssertEqual(first.rows[1], ["done ", "184.6", "", "false", "", ""])
    }

    func testReadRejectsGarbage() {
        XCTAssertThrowsError(try XLSX.read(Data("not a zip".utf8)))
    }
}
