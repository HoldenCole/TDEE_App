import SwiftUI
import UIKit

/// Design tokens from SCREENS.md section 1, with a dark counterpart for each that follows the system setting.
enum Theme {
    static let ink = Color(light: 0x15181D, dark: 0xF3F4F6)
    static let secondary = Color(light: 0x6B7280, dark: 0x9AA1AB)
    static let tertiary = Color(light: 0x9AA1AB, dark: 0x6B7280)
    static let hairline = Color(light: 0xECEEF1, dark: 0x262A31)
    static let track = Color(light: 0xEEF0F3, dark: 0x23272E)
    static let pill = Color(light: 0xF2F3F5, dark: 0x1C2026)
    static let accent = Color(light: 0x2453CC, dark: 0x6B97FF)
    static let accentTint = Color(light: 0x2453CC, dark: 0x6B97FF).opacity(0.12)
    static let coachStart = Color(hex: 0x1B3FA8)
    static let coachEnd = Color(hex: 0x2F63E0)
    static let good = Color(light: 0x1D7A50, dark: 0x4CC38A)
    static let behind = Color(light: 0x9A5A06, dark: 0xE2A64F)
    static let behindBar = Color(light: 0xC27A12, dark: 0xD08A2A)
    static let surface = Color(light: 0xFFFFFF, dark: 0x0F1115)
    /// Text on an ink-filled control: white in light mode, near-black in dark.
    static let onInk = Color(light: 0xFFFFFF, dark: 0x0F1115)
    /// The active segment of a segmented control, and slider thumbs.
    static let segmentActive = Color(light: 0xFFFFFF, dark: 0x2B3038)
    static let thumb = Color(light: 0xFFFFFF, dark: 0xE5E7EB)

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

    /// A color that resolves per appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
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
