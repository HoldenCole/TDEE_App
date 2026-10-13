import Foundation

/// A rectangular grid of strings with a header row. Ragged rows are padded to the column count.
public struct Table: Codable, Equatable, Sendable {
    public var columns: [String]
    public var rows: [[String]]

    public init(columns: [String], rows: [[String]] = []) {
        self.columns = columns
        self.rows = Table.pad(rows, to: columns.count)
    }

    public var isEmpty: Bool { columns.isEmpty && rows.isEmpty }

    /// Index of a column by exact name, then case-insensitive and whitespace-trimmed name.
    public func columnIndex(_ name: String) -> Int? {
        if let i = columns.firstIndex(of: name) { return i }
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return columns.firstIndex { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == wanted }
    }

    /// The value at `row` for the named column, or nil when the column does not exist.
    public func value(row: Int, column name: String) -> String? {
        guard let c = columnIndex(name), row >= 0, row < rows.count, c < rows[row].count else { return nil }
        return rows[row][c]
    }

    /// Appends a row, padding or truncating it to the column count.
    public mutating func append(_ row: [String]) {
        rows.append(Table.pad([row], to: columns.count)[0])
    }

    static func pad(_ rows: [[String]], to count: Int) -> [[String]] {
        rows.map { row in
            if row.count == count { return row }
            if row.count > count { return Array(row.prefix(count)) }
            return row + Array(repeating: "", count: count - row.count)
        }
    }
}

/// RFC 4180-style CSV reading and writing.
public enum CSV {

    /// Parses CSV text into a `Table`. The first record is the header.
    ///
    /// Handles quoted fields, embedded delimiters, newlines and doubled quotes, CRLF line
    /// endings and a leading UTF-8 BOM. When `delimiter` is nil the delimiter is detected from
    /// the header line (comma, semicolon or tab, whichever appears most outside quotes).
    public static func parse(_ text: String, delimiter: Character? = nil) -> Table {
        var text = text
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let delim = delimiter ?? detectDelimiter(in: text)
        let records = records(from: text, delimiter: delim)
        guard let header = records.first else { return Table(columns: []) }
        let columns = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var body = Array(records.dropFirst())
        // Drop fully blank trailing/interior records (a blank line in the file).
        body.removeAll { row in row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        return Table(columns: columns, rows: body)
    }

    /// Picks the delimiter used on the first line: comma, semicolon or tab.
    public static func detectDelimiter(in text: String) -> Character {
        var firstLine = ""
        var inQuotes = false
        for ch in text {
            if ch == "\"" { inQuotes.toggle() }
            if !inQuotes && (ch == "\n" || ch == "\r\n" || ch == "\r") { break }
            firstLine.append(ch)
        }
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        inQuotes = false
        for ch in firstLine {
            if ch == "\"" { inQuotes.toggle(); continue }
            if !inQuotes, counts[ch] != nil { counts[ch, default: 0] += 1 }
        }
        let best = counts.max { a, b in
            if a.value != b.value { return a.value < b.value }
            return order(a.key) > order(b.key)
        }
        guard let best, best.value > 0 else { return "," }
        return best.key
    }

    private static func order(_ c: Character) -> Int { c == "," ? 0 : (c == ";" ? 1 : 2) }

    /// Splits text into records of fields. Line terminators may be LF, CRLF or CR.
    public static func records(from text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var sawAnything = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let ch = next() {
            sawAnything = true
            if inQuotes {
                if ch == "\"" {
                    if let peek = next() {
                        if peek == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = peek
                        }
                    } else {
                        inQuotes = false
                    }
                } else if ch == "\r\n" {
                    field.append("\n")
                } else {
                    field.append(ch)
                }
                continue
            }
            if ch == "\"" {
                inQuotes = true
            } else if ch == delimiter {
                record.append(field)
                field = ""
            } else if ch == "\n" || ch == "\r\n" || ch == "\r" {
                record.append(field)
                field = ""
                records.append(record)
                record = []
            } else {
                field.append(ch)
            }
        }
        if sawAnything && (!field.isEmpty || !record.isEmpty) {
            record.append(field)
            records.append(record)
        }
        return records
    }

    /// Serializes a table as CSV with CRLF line endings. Fields containing the delimiter,
    /// quotes, or line breaks are quoted; quotes are doubled.
    public static func write(_ table: Table, delimiter: Character = ",", lineEnding: String = "\r\n") -> String {
        var lines: [String] = []
        lines.append(table.columns.map { quote($0, delimiter: delimiter) }.joined(separator: String(delimiter)))
        for row in table.rows {
            lines.append(row.map { quote($0, delimiter: delimiter) }.joined(separator: String(delimiter)))
        }
        return lines.joined(separator: lineEnding) + lineEnding
    }

    static func quote(_ field: String, delimiter: Character) -> String {
        let needs = field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r")
            || field.hasPrefix(" ") || field.hasSuffix(" ")
        guard needs else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
