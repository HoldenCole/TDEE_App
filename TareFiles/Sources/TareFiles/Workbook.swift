import Foundation

/// One worksheet: a name and its table.
public struct Sheet: Codable, Equatable, Sendable {
    public var name: String
    public var table: Table

    public init(name: String, table: Table) {
        self.name = name
        self.table = table
    }
}

/// An ordered set of sheets.
public struct Workbook: Codable, Equatable, Sendable {
    public var sheets: [Sheet]

    public init(sheets: [Sheet] = []) {
        self.sheets = sheets
    }

    /// The sheet with the given name (case-insensitive), if any.
    public func sheet(named name: String) -> Sheet? {
        let wanted = name.lowercased()
        return sheets.first { $0.name.lowercased() == wanted }
    }
}

/// Errors thrown while reading or writing .xlsx data.
public enum XLSXError: Error, Equatable, LocalizedError, Sendable {
    case notAZipArchive
    case missingPart(String)
    case malformedXML(String)
    case emptyWorkbook

    public var errorDescription: String? {
        switch self {
        case .notAZipArchive: return "The file is not a valid .xlsx archive."
        case .missingPart(let p): return "The workbook is missing \(p)."
        case .malformedXML(let p): return "Could not parse \(p)."
        case .emptyWorkbook: return "The workbook has no sheets."
        }
    }
}

/// Minimal Office Open XML spreadsheet reader and writer.
public enum XLSX {

    // MARK: - Writing

    /// Produces a valid .xlsx file. Strings that parse as numbers are written as numeric cells;
    /// everything else is written as an inline string. The header row is bold.
    public static func write(_ workbook: Workbook) throws -> Data {
        var files: [(String, Data)] = []
        let sheets = sanitizedSheets(workbook.sheets)

        var contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>

        """
        for i in sheets.indices {
            contentTypes += "<Override PartName=\"/xl/worksheets/sheet\(i + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>\n"
        }
        contentTypes += "</Types>"
        files.append(("[Content_Types].xml", Data(contentTypes.utf8)))

        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
        files.append(("_rels/.rels", Data(rels.utf8)))

        let app = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Tare</Application></Properties>
        """
        files.append(("docProps/app.xml", Data(app.utf8)))

        let stamp = iso8601Stamp(Date())
        let core = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:creator>Tare</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">\(stamp)</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">\(stamp)</dcterms:modified></cp:coreProperties>
        """
        files.append(("docProps/core.xml", Data(core.utf8)))

        var wb = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <workbookPr/>
        <bookViews><workbookView xWindow="0" yWindow="0" windowWidth="20000" windowHeight="12000"/></bookViews>
        <sheets>

        """
        var wbRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

        """
        for (i, sheet) in sheets.enumerated() {
            wb += "<sheet name=\"\(escape(sheet.name))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>\n"
            wbRels += "<Relationship Id=\"rId\(i + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i + 1).xml\"/>\n"
        }
        wb += "</sheets>\n<calcPr calcId=\"0\"/>\n</workbook>"
        let stylesRel = sheets.count + 1
        wbRels += "<Relationship Id=\"rId\(stylesRel)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>\n</Relationships>"
        files.append(("xl/workbook.xml", Data(wb.utf8)))
        files.append(("xl/_rels/workbook.xml.rels", Data(wbRels.utf8)))
        files.append(("xl/styles.xml", Data(minimalStyles.utf8)))

        for (i, sheet) in sheets.enumerated() {
            files.append(("xl/worksheets/sheet\(i + 1).xml", Data(sheetXML(sheet.table).utf8)))
        }

        return try Zip.archive(files)
    }

    static let minimalStyles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="2"><font><sz val="11"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font></fonts>
    <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
    <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
    <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """

    static func sheetXML(_ table: Table) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
        <sheetData>

        """
        func row(_ index: Int, _ values: [String], style: Int?) {
            xml += "<row r=\"\(index)\">"
            for (c, value) in values.enumerated() {
                let ref = columnLetters(c) + String(index)
                let s = style.map { " s=\"\($0)\"" } ?? ""
                if value.isEmpty { continue }
                if let number = numericCell(value) {
                    xml += "<c r=\"\(ref)\"\(s)><v>\(number)</v></c>"
                } else {
                    let preserve = value.first == " " || value.last == " " || value.contains("\n") ? " xml:space=\"preserve\"" : ""
                    xml += "<c r=\"\(ref)\" t=\"inlineStr\"\(s)><is><t\(preserve)>\(escape(value))</t></is></c>"
                }
            }
            xml += "</row>\n"
        }
        row(1, table.columns, style: 1)
        for (i, r) in table.rows.enumerated() {
            row(i + 2, r, style: nil)
        }
        xml += "</sheetData>\n</worksheet>"
        return xml
    }

    /// The text to put in a `<v>` for a string that is a plain number, or nil when the string
    /// should be stored as text (including leading-zero codes like "007").
    static func numericCell(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 40 else { return nil }
        var scalars = Substring(trimmed)
        if scalars.first == "+" || scalars.first == "-" { scalars = scalars.dropFirst() }
        guard let first = scalars.first, first.isNumber || first == "." else { return nil }
        var sawDigit = false, sawDot = false, sawExp = false
        var prev: Character = " "
        for ch in scalars {
            if ch.isASCII && ch.isNumber { sawDigit = true }
            else if ch == "." && !sawDot && !sawExp { sawDot = true }
            else if (ch == "e" || ch == "E") && sawDigit && !sawExp { sawExp = true }
            else if (ch == "+" || ch == "-") && (prev == "e" || prev == "E") {}
            else { return nil }
            prev = ch
        }
        guard sawDigit, let d = Double(trimmed), d.isFinite else { return nil }
        // Leading zeros (postal codes, IDs) stay text.
        if scalars.count > 1, scalars.first == "0", scalars.dropFirst().first != "." { return nil }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return "\(d)"
    }

    /// Excel sheet names: at most 31 characters, none of `[]:*?/\`, not empty, unique.
    public static func sanitizeSheetName(_ name: String) -> String {
        let forbidden: Set<Character> = ["[", "]", ":", "*", "?", "/", "\\"]
        var out = String(name.map { forbidden.contains($0) ? "-" : $0 })
        out = out.trimmingCharacters(in: .whitespaces)
        while out.hasPrefix("'") { out.removeFirst() }
        while out.hasSuffix("'") { out.removeLast() }
        if out.isEmpty { out = "Sheet" }
        if out.count > 31 { out = String(out.prefix(31)) }
        return out
    }

    static func sanitizedSheets(_ sheets: [Sheet]) -> [Sheet] {
        var seen: Set<String> = []
        var out: [Sheet] = []
        for (i, sheet) in sheets.enumerated() {
            var name = sanitizeSheetName(sheet.name.isEmpty ? "Sheet\(i + 1)" : sheet.name)
            var n = 2
            while seen.contains(name.lowercased()) {
                let suffix = " (\(n))"
                name = String(sanitizeSheetName(sheet.name).prefix(31 - suffix.count)) + suffix
                n += 1
            }
            seen.insert(name.lowercased())
            out.append(Sheet(name: name, table: sheet.table))
        }
        if out.isEmpty { out.append(Sheet(name: "Sheet1", table: Table(columns: []))) }
        return out
    }

    /// Zero-based column index to letters: 0 → A, 25 → Z, 26 → AA.
    public static func columnLetters(_ index: Int) -> String {
        var n = index + 1
        var s = ""
        while n > 0 {
            let r = (n - 1) % 26
            s = String(UnicodeScalar(UInt8(65 + r))) + s
            n = (n - 1) / 26
        }
        return s
    }

    /// Letters to zero-based column index: A → 0, AA → 26. Digits are ignored, so "B12" → 1.
    public static func columnIndex(_ ref: String) -> Int? {
        var n = 0
        var sawLetter = false
        for ch in ref.uppercased() {
            guard let a = ch.asciiValue else { return nil }
            if a >= 65 && a <= 90 {
                n = n * 26 + Int(a - 64)
                sawLetter = true
            } else if a >= 48 && a <= 57 {
                break
            } else if ch == "$" {
                continue
            } else {
                return nil
            }
        }
        return sawLetter ? n - 1 : nil
    }

    static func rowNumber(_ ref: String) -> Int? {
        let digits = ref.drop { !$0.isNumber }
        return Int(digits)
    }

    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\t", "\n", "\r": out.unicodeScalars.append(scalar)
            default:
                if scalar.value < 0x20 || scalar.value == 0xFFFE || scalar.value == 0xFFFF { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    static func iso8601Stamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Reading

    /// Parses an .xlsx file into a `Workbook`, sheets in workbook order. Shared strings,
    /// inline strings, rich-text runs, numbers, booleans and date-styled numbers are all
    /// turned into strings; dates become `yyyy-MM-dd` (plus ` HH:mm:ss` when the format shows
    /// a time of day). The first row of each sheet is its header.
    public static func read(_ data: Data) throws -> Workbook {
        let parts: [String: Data]
        do {
            parts = try Zip.unarchive(data)
        } catch {
            throw XLSXError.notAZipArchive
        }
        func part(_ name: String) -> Data? {
            if let d = parts[name] { return d }
            let wanted = name.lowercased()
            return parts.first { $0.key.lowercased() == wanted || $0.key.lowercased() == "/" + wanted }?.value
        }
        guard let workbookXML = part("xl/workbook.xml") else { throw XLSXError.missingPart("xl/workbook.xml") }

        let wbInfo = WorkbookParser()
        guard wbInfo.parse(workbookXML) else { throw XLSXError.malformedXML("xl/workbook.xml") }

        var relTargets: [String: String] = [:]
        if let relsData = part("xl/_rels/workbook.xml.rels") {
            let rp = RelsParser()
            if rp.parse(relsData) { relTargets = rp.targets }
        }

        var sharedStrings: [String] = []
        if let ssData = part("xl/sharedStrings.xml") {
            let sp = SharedStringsParser()
            if sp.parse(ssData) { sharedStrings = sp.strings }
        }

        var dateStyles: Set<Int> = []
        if let stData = part("xl/styles.xml") {
            let st = StylesParser()
            if st.parse(stData) { dateStyles = st.dateStyleIndexes }
        }

        var sheets: [Sheet] = []
        for (i, sheetRef) in wbInfo.sheets.enumerated() {
            var target = sheetRef.relID.flatMap { relTargets[$0] } ?? "worksheets/sheet\(i + 1).xml"
            if target.hasPrefix("/") { target.removeFirst() } else { target = "xl/" + target }
            guard let sheetData = part(target) else { continue }
            let parser = SheetParser(sharedStrings: sharedStrings, dateStyles: dateStyles, date1904: wbInfo.date1904)
            guard parser.parse(sheetData) else { throw XLSXError.malformedXML(target) }
            sheets.append(Sheet(name: sheetRef.name, table: parser.table()))
        }
        guard !sheets.isEmpty else { throw XLSXError.emptyWorkbook }
        return Workbook(sheets: sheets)
    }

    // MARK: Excel serial dates

    /// Converts an Excel serial date to `yyyy-MM-dd`, adding ` HH:mm:ss` when `withTime` is set
    /// and the serial has a time-of-day component.
    public static func dateString(fromSerial serial: Double, date1904: Bool = false, withTime: Bool = false) -> String {
        var days = serial
        if !date1904 && serial < 61 { days += 1 } // Excel's phantom 29 Feb 1900
        let epoch: TimeInterval = date1904 ? -2082844800 : -2209161600 // 1904-01-01 / 1899-12-30 UTC
        let seconds = (days * 86400).rounded()
        let date = Date(timeIntervalSince1970: epoch + seconds)
        let hasTime = seconds.truncatingRemainder(dividingBy: 86400) != 0
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = (withTime && hasTime) ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Formats a numeric `<v>` value the way a person would type it: integers without a
    /// decimal point, others as the shortest round-trip representation.
    static func formatNumber(_ raw: String) -> String {
        guard let d = Double(raw), d.isFinite else { return raw }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        // Excel stores 15 significant digits; round away binary noise such as 184.59999999999999
        let rounded = (d * 1e10).rounded() / 1e10
        return "\(rounded)"
    }
}
