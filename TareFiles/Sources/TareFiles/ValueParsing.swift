import Foundation

/// Lenient number parsing for spreadsheet cells: thousands separators, a leading "+",
/// trailing units ("184.6 lb", "18.5%") and decimal commas.
public enum NumberParsing {

    public static func double(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        if lower == "true" || lower == "yes" { return 1 }
        if lower == "false" || lower == "no" { return 0 }
        if lower == "nan" || lower == "n/a" || lower == "na" || lower == "-" || lower == "--" { return nil }
        s = s.replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: " ", with: "")

        // Take the leading numeric token: sign, digits, separators, exponent.
        var token = ""
        var sawDigit = false
        var sawExp = false
        var prev: Character = " "
        for ch in s {
            if ch.isASCII && ch.isNumber { token.append(ch); sawDigit = true }
            else if ch == "." || ch == "," { token.append(ch) }
            else if (ch == "+" || ch == "-") && (token.isEmpty || prev == "e" || prev == "E") { token.append(ch) }
            else if (ch == "e" || ch == "E") && sawDigit && !sawExp { token.append(ch); sawExp = true }
            else { break }
            prev = ch
        }
        guard sawDigit else { return nil }
        // Drop a dangling exponent marker ("5e" from "5 easy").
        while let last = token.last, last == "e" || last == "E" || last == "+" || last == "-" || last == "." || last == "," {
            token.removeLast()
        }
        token = normalizeSeparators(token)
        if token.hasPrefix("+") { token.removeFirst() }
        guard let d = Double(token), d.isFinite else { return nil }
        return d
    }

    public static func int(_ raw: String) -> Int? {
        guard let d = double(raw) else { return nil }
        return Int(d.rounded())
    }

    /// Converts "1,234.5", "1.234,5", "1,234" and "184,6" into a `Double`-parseable string.
    static func normalizeSeparators(_ token: String) -> String {
        let commas = token.filter { $0 == "," }.count
        let dots = token.filter { $0 == "." }.count
        if commas == 0 { return dots > 1 ? token.replacingOccurrences(of: ".", with: "") : token }
        if dots == 0 {
            if commas == 1, let idx = token.firstIndex(of: ","), token[token.index(after: idx)...].count != 3 {
                return token.replacingOccurrences(of: ",", with: ".")
            }
            return token.replacingOccurrences(of: ",", with: "")
        }
        // Both present: the last one is the decimal separator.
        let lastComma = token.lastIndex(of: ",")!
        let lastDot = token.lastIndex(of: ".")!
        if lastDot > lastComma {
            return token.replacingOccurrences(of: ",", with: "")
        } else {
            return token.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
    }

    public static func bool(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "y", "1", "on", "x", "✓", "complete", "completed", "done": return true
        case "false", "no", "n", "0", "off", "incomplete": return false
        default: return nil
        }
    }
}

/// Lenient date parsing for the formats seen in Hevy, Strong, MacroFactor, Cronometer,
/// MyFitnessPal, Apple Health and hand-typed spreadsheets.
public enum DateParsing {

    /// Patterns tried in order after any caller-supplied formats.
    public static let builtinFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "yyyy/MM/dd HH:mm:ss",
        "yyyy/MM/dd HH:mm",
        "yyyy/MM/dd",
        "yyyy.MM.dd",
        "yyyyMMdd",
        "d MMM yyyy, HH:mm",
        "d MMM yyyy, h:mm a",
        "d MMM yyyy HH:mm",
        "d MMM yyyy h:mm a",
        "d MMM yyyy",
        "d MMMM yyyy, HH:mm",
        "d MMMM yyyy",
        "MMM d, yyyy HH:mm",
        "MMM d, yyyy h:mm a",
        "MMM d, yyyy",
        "MMM d yyyy",
        "MMMM d, yyyy",
        "EEE, d MMM yyyy HH:mm",
        "EEEE, MMMM d, yyyy",
        "dd.MM.yyyy HH:mm",
        "dd.MM.yyyy",
    ]

    private static let utc = TimeZone(identifier: "UTC")!

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoSpace: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone, .withSpaceBetweenDateAndTime]
        return f
    }()

    static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = format
        f.isLenient = false
        return f
    }

    /// Parses a date string. Date-only values are midnight in `timeZone` (the current zone by
    /// default); values that carry an offset keep it. Slash dates are read as M/d/yyyy unless
    /// the first number can only be a day (d/M/yyyy) — ambiguous ones default to M/d.
    public static func date(_ raw: String, extraFormats: [String] = [], timeZone: TimeZone = .current) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // ISO 8601 with an offset or Z
        if s.contains("T") || s.contains("Z") || s.contains("+") || s.hasSuffix("z") {
            if let d = isoFractional.date(from: s) ?? isoPlain.date(from: s) { return d }
            // Offsets written without a colon, or with lowercase z
            let fixed = s.uppercased()
            if let d = isoFractional.date(from: fixed) ?? isoPlain.date(from: fixed) { return d }
        }
        if s.count >= 20, let d = isoSpace.date(from: s) { return d }
        if let d = parseOffsetSuffix(s, timeZone: timeZone) { return d }

        for format in extraFormats {
            if let d = formatter(format, timeZone: timeZone).date(from: s) { return d }
        }
        if let d = parseSlashDate(s, timeZone: timeZone) { return d }
        for format in builtinFormats {
            if let d = formatter(format, timeZone: timeZone).date(from: s) { return d }
        }
        // Excel serial typed as text (e.g. 46308 or 46308.5), only when clearly in range.
        if let n = Double(s), n > 20000, n < 80000, !s.contains("/") {
            let iso = XLSX.dateString(fromSerial: n, withTime: true)
            return formatter(iso.count > 10 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd", timeZone: timeZone).date(from: iso)
        }
        return nil
    }

    /// "2026-10-13 07:15:00 +0000" / "2026-10-13 07:15:00 -0500" (Apple Health exports).
    private static func parseOffsetSuffix(_ s: String, timeZone: TimeZone) -> Date? {
        guard s.count >= 25, let space = s.lastIndex(of: " ") else { return nil }
        let tail = s[s.index(after: space)...]
        guard tail.count == 5, tail.first == "+" || tail.first == "-", tail.dropFirst().allSatisfy(\.isNumber) else { return nil }
        for format in ["yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd HH:mm Z"] {
            if let d = formatter(format, timeZone: timeZone).date(from: s) { return d }
        }
        return nil
    }

    /// M/d/yyyy, d/M/yyyy (only when the first number exceeds 12), M/d/yy, with optional time.
    private static func parseSlashDate(_ s: String, timeZone: TimeZone) -> Date? {
        guard s.contains("/") else { return nil }
        let datePart = s.split(separator: " ", maxSplits: 1).first.map(String.init) ?? s
        let pieces = datePart.split(separator: "/")
        guard pieces.count == 3, let a = Int(pieces[0]), let b = Int(pieces[1]), pieces[2].count >= 2 else { return nil }
        // yyyy/M/d is handled by the builtin formats
        if pieces[0].count == 4 { return nil }
        let dayFirst = a > 12 && b <= 12
        let year = pieces[2].count == 2 ? "yy" : "yyyy"
        let dateFormat = dayFirst ? "d/M/\(year)" : "M/d/\(year)"
        let timeSuffixes = ["", " HH:mm:ss", " HH:mm", " h:mm:ss a", " h:mm a", " H:mm"]
        for suffix in timeSuffixes {
            if let d = formatter(dateFormat + suffix, timeZone: timeZone).date(from: s) { return d }
        }
        return nil
    }

    private static let dayFormatter: DateFormatter = formatter("yyyy-MM-dd", timeZone: .current)

    /// `yyyy-MM-dd` in the current time zone.
    public static func dayString(_ date: Date, timeZone: TimeZone = .current) -> String {
        if timeZone == TimeZone.current { return dayFormatter.string(from: date) }
        return formatter("yyyy-MM-dd", timeZone: timeZone).string(from: date)
    }
}
