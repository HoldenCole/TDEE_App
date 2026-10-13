import SwiftUI

/// Design tokens from SCREENS.md section 1.
enum Theme {
    static let ink = Color(hex: 0x15181D)
    static let secondary = Color(hex: 0x6B7280)
    static let tertiary = Color(hex: 0x9AA1AB)
    static let hairline = Color(hex: 0xECEEF1)
    static let track = Color(hex: 0xEEF0F3)
    static let pill = Color(hex: 0xF2F3F5)
    static let accent = Color(hex: 0x2453CC)
    static let accentTint = Color(hex: 0x2453CC).opacity(0.08)
    static let coachStart = Color(hex: 0x1B3FA8)
    static let coachEnd = Color(hex: 0x2F63E0)
    static let good = Color(hex: 0x1D7A50)
    static let behind = Color(hex: 0x9A5A06)
    static let behindBar = Color(hex: 0xC27A12)
    static let surface = Color.white

    static let coachGradient = LinearGradient(colors: [coachStart, coachEnd], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let sideMargin: CGFloat = 24
    static let buttonRadius: CGFloat = 13
    static let cardRadius: CGFloat = 20
    static let sheetRadius: CGFloat = 28

    // Type. SF Pro stands in for Geist, same sizes and weights.
    static func hero() -> Font { .system(size: 72, weight: .bold) }
    static func large(_ size: CGFloat = 48) -> Font { .system(size: size, weight: .bold) }
    static func title() -> Font { .system(size: 26, weight: .bold) }
    static func stat() -> Font { .system(size: 22, weight: .bold) }
    static func section() -> Font { .system(size: 21, weight: .bold) }
    static func body(_ weight: Font.Weight = .regular) -> Font { .system(size: 15, weight: weight) }
    static func bodySmall(_ weight: Font.Weight = .regular) -> Font { .system(size: 14, weight: weight) }
    static func caption() -> Font { .system(size: 13, weight: .regular) }
    static func captionSmall() -> Font { .system(size: 12, weight: .regular) }
    static func eyebrow() -> Font { .system(size: 11, weight: .semibold) }
    static func axis() -> Font { .system(size: 10, weight: .regular) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Tracking expressed as a percentage of the font size, as the spec gives it.
    func tracking(percent: Double, of size: CGFloat) -> some View {
        self.tracking(size * percent / 100)
    }
}

extension Text {
    func heroStyle() -> some View {
        self.font(Theme.hero()).monospacedDigit().foregroundStyle(Theme.ink).tracking(percent: -4, of: 72)
    }
    func largeStyle(_ size: CGFloat = 48) -> some View {
        self.font(Theme.large(size)).monospacedDigit().foregroundStyle(Theme.ink).tracking(percent: -4, of: size)
    }
    func titleStyle() -> some View {
        self.font(Theme.title()).foregroundStyle(Theme.ink).tracking(percent: -2, of: 26)
    }
    func statStyle(_ color: Color = Theme.ink) -> some View {
        self.font(Theme.stat()).monospacedDigit().foregroundStyle(color).tracking(percent: -2, of: 22)
    }
    func sectionStyle() -> some View {
        self.font(Theme.section()).foregroundStyle(Theme.ink).tracking(percent: -2, of: 21)
    }
    func eyebrowStyle(_ color: Color = Theme.secondary) -> some View {
        self.font(Theme.eyebrow()).foregroundStyle(color).textCase(.uppercase).tracking(percent: 9, of: 11)
    }
    func captionStyle(_ color: Color = Theme.secondary) -> some View {
        self.font(Theme.caption()).foregroundStyle(color)
    }
    func bodyStyle(_ weight: Font.Weight = .regular, color: Color = Theme.ink) -> some View {
        self.font(Theme.body(weight)).foregroundStyle(color)
    }
}

// MARK: - Number formatting

enum Fmt {
    static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func int(_ v: Double) -> String {
        integer.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v.rounded()))"
    }

    static func int(_ v: Int) -> String { int(Double(v)) }

    static func dec(_ v: Double, _ digits: Int = 1) -> String {
        String(format: "%.\(digits)f", v)
    }

    static func signed(_ v: Double, _ digits: Int = 1, suffix: String = "") -> String {
        let s = digits == 0 ? int(abs(v)) : dec(abs(v), digits)
        let sign = v > 0 ? "+" : (v < 0 ? "−" : "")
        return sign + s + suffix
    }

    static func percent(_ v: Double, _ digits: Int = 0) -> String {
        dec(v, digits) + "%"
    }

    static func lb(_ v: Double) -> String { dec(v, 1) }

    static func rate(_ lbPerWeek: Double) -> String { signed(lbPerWeek, 2, suffix: " lb/wk") }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    static func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    static func heightFeetInches(cm: Double) -> String {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet) * 12).rounded())
        return "\(feet)′ \(inches)″"
    }
}
