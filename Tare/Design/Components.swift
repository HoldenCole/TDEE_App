import SwiftUI

// MARK: - Layout primitives

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

struct VerticalHairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.secondary
    init(_ text: String, color: Color = Theme.secondary) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text).eyebrowStyle(color)
    }
}

/// Screen header: kicker line in secondary, the title, and an optional trailing control.
struct ScreenHeader<Trailing: View>: View {
    let kicker: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(kicker: String, title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.kicker = kicker
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kicker).font(Theme.body()).foregroundStyle(Theme.secondary)
                Text(title).titleStyle()
            }
            Spacer()
            trailing()
        }
        .padding(.top, 28)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(kicker: String, title: String) {
        self.init(kicker: kicker, title: title) { EmptyView() }
    }
}

/// The one continuous white surface each screen scrolls on.
struct Screen<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.bottom, 40)
        }
        .background(Theme.surface)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Tappable numbers

/// Any value from data or the engine: dotted accent underline, opens the number-detail sheet.
struct DottedNumber: View {
    @Environment(AppModel.self) private var model
    let text: String
    let number: NumberID
    var font: Font = Theme.stat()
    var color: Color = Theme.ink
    var tracking: CGFloat = 0

    var body: some View {
        Button {
            model.showDetail(number)
        } label: {
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(color)
                .tracking(tracking)
                .underline(true, pattern: .dot, color: Theme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("number.\(number.id)")
    }
}

// MARK: - Pills and buttons

struct PillChip: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(.semibold))
                .foregroundStyle(active ? Theme.onInk : Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(active ? Theme.ink : Theme.pill))
        }
        .buttonStyle(.plain)
    }
}

struct PillButton: View {
    let title: String
    var tint: Color = Theme.ink
    var background: Color = Theme.pill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(background))
        }
        .buttonStyle(.plain)
    }
}

struct InkButton: View {
    let title: String
    var fill: Color = Theme.ink
    var foreground: Color = Theme.onInk
    var expand: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: expand ? .infinity : nil)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
    }
}

struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.pill))
        }
        .buttonStyle(.plain)
    }
}

/// Pill-shaped segmented control; the active segment is white on the pill-grey track.
struct SegmentedPills<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = value }
                } label: {
                    Text(title)
                        .font(Theme.bodySmall(.semibold))
                        .foregroundStyle(selection == value ? Theme.ink : Theme.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selection == value ? Theme.segmentActive : Color.clear).shadow(color: .black.opacity(selection == value ? 0.08 : 0), radius: 3, y: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.pill))
    }
}

// MARK: - Bars

struct BarView: View {
    let fraction: Double
    var height: CGFloat = 6
    var color: Color = Theme.ink
    var track: Color = Theme.track

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Slider

/// 4–6 px track, white thumb with a soft shadow. Fill is ink, or accent when the dial is off its default.
struct TareSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var tint: Color = Theme.ink
    var onEditingChanged: ((Bool) -> Void)? = nil

    private let thumbSize: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let fraction = (value - range.lowerBound) / max(0.000001, range.upperBound - range.lowerBound)
            let x = max(0, min(1, fraction)) * width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track).frame(height: 5)
                Capsule().fill(tint).frame(width: x + thumbSize / 2, height: 5)
                Circle()
                    .fill(Theme.thumb)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = max(0, min(1, (g.location.x - thumbSize / 2) / width))
                        var v = range.lowerBound + f * (range.upperBound - range.lowerBound)
                        if step > 0 { v = (v / step).rounded() * step }
                        v = max(range.lowerBound, min(range.upperBound, v))
                        if v != value {
                            value = v
                            onEditingChanged?(true)
                        }
                    }
                    .onEnded { _ in onEditingChanged?(false) }
            )
        }
        .frame(height: thumbSize)
    }
}

// MARK: - Rows

/// A setting row: title and optional subtitle on the left, a value and chevron on the right.
struct SettingRow<Value: View>: View {
    let title: String
    var subtitle: String? = nil
    var chevron: Bool = true
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle).font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            value()
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

struct StatCell: View {
    let label: String
    let value: AnyView
    let caption: String
    var captionColor: Color = Theme.secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(label)
            value
            Text(caption).font(Theme.caption()).foregroundStyle(captionColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Toast

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

struct ToastView: View {
    let toast: Toast
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(toast.message).font(Theme.bodySmall(.semibold)).foregroundStyle(Theme.onInk)
            Spacer()
            if let title = toast.actionTitle {
                Button(title) {
                    toast.action?()
                    dismiss()
                }
                .font(Theme.bodySmall(.semibold))
                .foregroundStyle(Color(hex: 0x8FB0FF))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
        .padding(.horizontal, Theme.sideMargin)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

// MARK: - Misc

struct SparklineView: View {
    let values: [Double]
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, 0.0001)
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.body())
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
    }
}
