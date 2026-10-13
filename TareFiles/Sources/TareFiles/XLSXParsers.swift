import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Base class: runs Foundation's XMLParser and strips namespace prefixes from element names.
class XMLPartParser: NSObject, XMLParserDelegate {
    private(set) var failed = false

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        let ok = parser.parse()
        return ok && !failed
    }

    static func localName(_ qualified: String) -> String {
        if let colon = qualified.lastIndex(of: ":") { return String(qualified[qualified.index(after: colon)...]) }
        return qualified
    }

    /// Attribute lookup that tolerates namespace prefixes ("r:id" matches "id").
    static func attr(_ attributes: [String: String], _ name: String) -> String? {
        if let v = attributes[name] { return v }
        for (k, v) in attributes where localName(k) == name { return v }
        return nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        start(Self.localName(elementName), attributeDict)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        end(Self.localName(elementName))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characters(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) { characters(s) }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        failed = true
    }

    func start(_ name: String, _ attributes: [String: String]) {}
    func end(_ name: String) {}
    func characters(_ text: String) {}
}

/// xl/workbook.xml: ordered sheet list and the 1904 date flag.
final class WorkbookParser: XMLPartParser {
    struct SheetRef { let name: String; let relID: String? }
    var sheets: [SheetRef] = []
    var date1904 = false

    override func start(_ name: String, _ attributes: [String: String]) {
        switch name {
        case "sheet":
            let sheetName = Self.attr(attributes, "name") ?? "Sheet\(sheets.count + 1)"
            sheets.append(SheetRef(name: sheetName, relID: Self.attr(attributes, "id")))
        case "workbookPr":
            if let v = Self.attr(attributes, "date1904") { date1904 = v == "1" || v.lowercased() == "true" }
        default: break
        }
    }
}

/// xl/_rels/workbook.xml.rels: relationship id → target path.
final class RelsParser: XMLPartParser {
    var targets: [String: String] = [:]

    override func start(_ name: String, _ attributes: [String: String]) {
        guard name == "Relationship", let id = Self.attr(attributes, "Id"), let target = Self.attr(attributes, "Target") else { return }
        targets[id] = target
    }
}

/// xl/sharedStrings.xml: each `<si>` becomes one string; `<r>` runs are concatenated and
/// phonetic `<rPh>` runs are skipped.
final class SharedStringsParser: XMLPartParser {
    var strings: [String] = []
    private var current = ""
    private var inSI = false
    private var inT = false
    private var phoneticDepth = 0

    override func start(_ name: String, _ attributes: [String: String]) {
        switch name {
        case "si": inSI = true; current = ""
        case "rPh": phoneticDepth += 1
        case "t": inT = inSI && phoneticDepth == 0
        default: break
        }
    }

    override func end(_ name: String) {
        switch name {
        case "si": strings.append(current); inSI = false
        case "rPh": phoneticDepth = max(0, phoneticDepth - 1)
        case "t": inT = false
        default: break
        }
    }

    override func characters(_ text: String) {
        if inT { current += text }
    }
}

/// xl/styles.xml: which cellXfs indexes carry a date or time number format.
final class StylesParser: XMLPartParser {
    var dateStyleIndexes: Set<Int> = []
    private var customDateFormats: Set<Int> = []
    private var inCellXfs = false
    private var xfIndex = 0

    static let builtinDateFormats: Set<Int> = Set(14...22).union(Set(45...47))

    static func looksLikeDate(_ code: String) -> Bool {
        // Strip quoted literals, colours and escaped characters, then look for date tokens.
        var cleaned = ""
        var inQuote = false
        var skipNext = false
        var inBracket = false
        for ch in code {
            if skipNext { skipNext = false; continue }
            if inQuote { if ch == "\"" { inQuote = false }; continue }
            if inBracket { if ch == "]" { inBracket = false }; continue }
            switch ch {
            case "\"": inQuote = true
            case "[": inBracket = true
            case "\\": skipNext = true
            default: cleaned.append(ch)
            }
        }
        let lower = cleaned.lowercased()
        if lower.contains("general") { return false }
        return lower.contains("y") || lower.contains("d") || lower.contains("h") || lower.contains("m")
    }

    override func start(_ name: String, _ attributes: [String: String]) {
        switch name {
        case "numFmt":
            if let idText = Self.attr(attributes, "numFmtId"), let id = Int(idText),
               let code = Self.attr(attributes, "formatCode"), Self.looksLikeDate(code) {
                customDateFormats.insert(id)
            }
        case "cellXfs":
            inCellXfs = true
            xfIndex = 0
        case "xf" where inCellXfs:
            if let idText = Self.attr(attributes, "numFmtId"), let id = Int(idText),
               Self.builtinDateFormats.contains(id) || customDateFormats.contains(id) {
                dateStyleIndexes.insert(xfIndex)
            }
            xfIndex += 1
        default: break
        }
    }

    override func end(_ name: String) {
        if name == "cellXfs" { inCellXfs = false }
    }
}

/// xl/worksheets/sheetN.xml: a sparse grid of cell strings.
final class SheetParser: XMLPartParser {
    private let sharedStrings: [String]
    private let dateStyles: Set<Int>
    private let date1904: Bool

    private var grid: [Int: [Int: String]] = [:] // row (1-based) → column (0-based) → text
    private var maxColumn = -1
    private var maxRow = 0

    private var currentRow = 0
    private var nextColumn = 0
    private var inSheetData = false

    private var cellColumn = 0
    private var cellType = ""
    private var cellStyle: Int? = nil
    private var inCell = false
    private var inV = false
    private var inIS = false
    private var inT = false
    private var phoneticDepth = 0
    private var vText = ""
    private var isText = ""

    init(sharedStrings: [String], dateStyles: Set<Int>, date1904: Bool) {
        self.sharedStrings = sharedStrings
        self.dateStyles = dateStyles
        self.date1904 = date1904
    }

    override func start(_ name: String, _ attributes: [String: String]) {
        switch name {
        case "sheetData":
            inSheetData = true
        case "row" where inSheetData:
            if let r = Self.attr(attributes, "r").flatMap(Int.init), r > 0 { currentRow = r } else { currentRow += 1 }
            nextColumn = 0
        case "c" where inSheetData:
            inCell = true
            if let ref = Self.attr(attributes, "r") {
                if let col = XLSX.columnIndex(ref) { cellColumn = col } else { cellColumn = nextColumn }
                if let row = XLSX.rowNumber(ref), row > 0 { currentRow = row }
            } else {
                cellColumn = nextColumn
            }
            nextColumn = cellColumn + 1
            cellType = Self.attr(attributes, "t") ?? "n"
            cellStyle = Self.attr(attributes, "s").flatMap(Int.init)
            vText = ""
            isText = ""
        case "v" where inCell:
            inV = true
        case "is" where inCell:
            inIS = true
        case "rPh":
            phoneticDepth += 1
        case "t" where inIS:
            inT = phoneticDepth == 0
        default: break
        }
    }

    override func end(_ name: String) {
        switch name {
        case "sheetData": inSheetData = false
        case "c" where inCell:
            inCell = false
            let text = cellText()
            if !text.isEmpty {
                grid[currentRow, default: [:]][cellColumn] = text
                maxColumn = max(maxColumn, cellColumn)
                maxRow = max(maxRow, currentRow)
            }
        case "v": inV = false
        case "is": inIS = false
        case "t": inT = false
        case "rPh": phoneticDepth = max(0, phoneticDepth - 1)
        default: break
        }
    }

    override func characters(_ text: String) {
        if inV { vText += text }
        else if inT { isText += text }
    }

    private func cellText() -> String {
        switch cellType {
        case "s":
            guard let i = Int(vText.trimmingCharacters(in: .whitespacesAndNewlines)), i >= 0, i < sharedStrings.count else { return "" }
            return sharedStrings[i]
        case "inlineStr":
            return isText
        case "b":
            let v = vText.trimmingCharacters(in: .whitespacesAndNewlines)
            return v == "1" || v.lowercased() == "true" ? "true" : "false"
        case "str", "e":
            return vText
        case "d":
            return vText.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            let raw = vText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return "" }
            if let style = cellStyle, dateStyles.contains(style), let serial = Double(raw) {
                return XLSX.dateString(fromSerial: serial, date1904: date1904, withTime: true)
            }
            return XLSX.formatNumber(raw)
        }
    }

    func table() -> Table {
        guard maxRow >= 1 else { return Table(columns: []) }
        let width = maxColumn + 1
        func rowValues(_ r: Int) -> [String] {
            let cells = grid[r] ?? [:]
            return (0..<width).map { cells[$0] ?? "" }
        }
        // Header is the first non-empty row.
        var headerRow = 1
        while headerRow <= maxRow, (grid[headerRow] ?? [:]).isEmpty { headerRow += 1 }
        guard headerRow <= maxRow else { return Table(columns: []) }
        var columns = rowValues(headerRow).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Drop trailing unnamed columns that hold no data.
        while let last = columns.last, last.isEmpty {
            let col = columns.count - 1
            let hasData = grid.contains { $0.key > headerRow && !($0.value[col] ?? "").isEmpty }
            if hasData { break }
            columns.removeLast()
        }
        let w = columns.count
        var rows: [[String]] = []
        if headerRow < maxRow {
            for r in (headerRow + 1)...maxRow {
                let values = Array(rowValues(r).prefix(w))
                if values.allSatisfy({ $0.isEmpty }) { continue }
                rows.append(values)
            }
        }
        return Table(columns: columns, rows: rows)
    }
}
