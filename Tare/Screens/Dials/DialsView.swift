import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import TareEngine

struct DialsView: View {
    @Environment(AppModel.self) private var model
    @State private var group: DialGroup = .body
    @State private var showSearch = false

    private var d: Dials { model.dials }

    private var specs: [DialSpec] { DialCatalog.specs(for: d) }

    private var visibleSpecs: [DialSpec] {
        let query = model.dialsSearch.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            return specs.filter { $0.title.lowercased().contains(query) || $0.note.lowercased().contains(query) || $0.group.title.lowercased().contains(query) }
        }
        switch group {
        case .body: return specs.filter { $0.group == .profile || $0.group == .body }
        default: return specs.filter { $0.group == group }
        }
    }

    /// Specs grouped by spec-table row, in catalog order.
    private var rows: [(row: String, specs: [DialSpec])] {
        var order: [String] = []
        var byRow: [String: [DialSpec]] = [:]
        for s in visibleSpecs {
            if byRow[s.row] == nil { order.append(s.row) }
            byRow[s.row, default: []].append(s)
        }
        return order.map { ($0, byRow[$0] ?? []) }
    }

    private var chips: [DialGroup] {
        [.body, .bmr, .activity, .digestion, .adaptive, .goal, .cycling, .macros, .coach, .progress, .display]
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Screen {
                let changed = DialCatalog.changedCoreRows(in: d).count
                ScreenHeader(kicker: "\(DialCatalog.coreRowCount(for: d)) dials · \(changed) changed from default", title: "Dials") {
                    RoundIconButton(systemName: showSearch ? "xmark" : "magnifyingglass") {
                        withAnimation { showSearch.toggle() }
                        if !showSearch { model.dialsSearch = "" }
                    }
                }
                .padding(.bottom, 20)

                if showSearch {
                    TextField("Search dials", text: $model.dialsSearch)
                        .font(Theme.body())
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.pill))
                        .padding(.bottom, 16)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { g in
                            PillChip(title: g.title, active: group == g && model.dialsSearch.isEmpty) {
                                group = g
                                model.dialsSearch = ""
                            }
                        }
                    }
                }
                .padding(.bottom, 10)

                if group == .body && model.dialsSearch.isEmpty {
                    PresetsBlock()
                    Hairline()
                }

                ForEach(rows, id: \.row) { row in
                    DialRowBlock(specs: row.specs)
                    Hairline()
                }

                if group == .body && model.dialsSearch.isEmpty {
                    NavigationLink {
                        DataSourcesView()
                    } label: {
                        SettingRow(title: "Data sources", subtitle: dataSourcesSubtitle) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                    Hairline()
                }

                if group == .display || !model.dialsSearch.isEmpty {
                    ChangeLogBlock()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let filter = model.dialsGroupFilter {
                    group = filter == .profile ? .body : filter
                    model.dialsGroupFilter = nil
                }
            }
            .onChange(of: model.dialsGroupFilter) { _, new in
                if let new { group = new == .profile ? .body : new; model.dialsGroupFilter = nil }
            }
        }
    }

    private var dataSourcesSubtitle: String {
        var parts: [String] = []
        parts.append(AppState.healthAuthorized ? "Health connected" : "Health not connected")
        if AppState.hevyLastSync != nil { parts.append("Hevy") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - One spec-table row

struct DialRowBlock: View {
    @Environment(AppModel.self) private var model
    let specs: [DialSpec]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(specs.enumerated()), id: \.element.key) { index, spec in
                DialControl(spec: spec, compact: index > 0)
                    .padding(.vertical, index == 0 ? 18 : 8)
                    .padding(.leading, index > 0 ? 16 : 0)
            }
        }
    }
}

/// Renders one dial by its kind.
struct DialControl: View {
    @Environment(AppModel.self) private var model
    let spec: DialSpec
    var compact = false

    @State private var dragStart: DialValue?
    @State private var showNumberEntry = false
    @State private var numberText = ""

    private var value: DialValue { model.dials.value(for: spec.key) }
    private var isDefault: Bool { value == spec.defaultValue }
    private var sensitivity: Double { (isDefault || !spec.affectsTarget) ? 0 : model.sensitivity(for: spec.key) }

    var body: some View {
        switch spec.kind {
        case .slider(let lo, let hi, let step):
            sliderBody(lo: lo, hi: hi, step: step)
        case .choice(let choices):
            choiceBody(choices)
        case .toggle:
            toggleBody
        case .number(_, _, let allowsOff):
            numberBody(allowsOff: allowsOff)
        case .date(let allowsNone):
            dateBody(allowsNone: allowsNone)
        case .weekdaySet:
            weekdaySetBody
        case .weekdayOffsets:
            weekdayOffsetsBody
        }
    }

    // MARK: Slider

    private func sliderBody(lo: Double, hi: Double, step: Double) -> some View {
        let v = value.doubleValue ?? lo
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(spec.title).font(compact ? Theme.body(.semibold) : .system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(DialFormat.number(v, step: step)).font(.system(size: compact ? 17 : 20, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    if !spec.unit.isEmpty {
                        Text(spec.unit).font(Theme.body()).foregroundStyle(Theme.secondary)
                    }
                }
                if sensitivity != 0 {
                    SensitivityBadge(kcal: sensitivity, key: spec.key)
                }
            }
            TareSlider(
                value: Binding(get: { v }, set: { model.previewDial(spec.key, .number($0)) }),
                range: lo...hi,
                step: step,
                tint: isDefault ? Theme.ink : Theme.accent
            ) { editing in
                if editing, dragStart == nil { dragStart = value }
                if !editing, let start = dragStart {
                    model.commitDial(spec.key, from: start)
                    dragStart = nil
                }
            }
            noteRow
        }
    }

    private var noteRow: some View {
        HStack(alignment: .bottom) {
            if !spec.note.isEmpty {
                Text(spec.note).font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !isDefault {
                Button("Reset") { model.resetDial(spec.key) }
                    .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
            }
        }
    }

    // MARK: Choice

    private func choiceBody(_ choices: [DialChoice]) -> some View {
        let current = value.choiceValue ?? ""
        let title = choices.first { $0.id == current }?.title ?? current
        return Menu {
            ForEach(choices, id: \.id) { c in
                Button {
                    model.setDial(spec.key, .choice(c.id))
                } label: {
                    if c.id == current { Label(c.title, systemImage: "checkmark") } else { Text(c.title) }
                }
            }
        } label: {
            SettingRow(title: spec.title, subtitle: compact ? nil : (spec.note.isEmpty ? nil : spec.note)) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.secondary)
                    if sensitivity != 0 { SensitivityBadge(kcal: sensitivity, key: spec.key) }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Toggle

    private var toggleBody: some View {
        SettingRow(title: spec.title, subtitle: compact ? nil : (spec.note.isEmpty ? nil : spec.note), chevron: false) {
            HStack(spacing: 8) {
                if sensitivity != 0 { SensitivityBadge(kcal: sensitivity, key: spec.key) }
                Toggle("", isOn: Binding(get: { value.boolValue ?? false }, set: { model.setDial(spec.key, .bool($0)) }))
                    .labelsHidden()
                    .tint(Theme.ink)
            }
        }
    }

    // MARK: Number

    private func numberBody(allowsOff: Bool) -> some View {
        let text: String
        switch value {
        case .optionalNumber(let v): text = v.map { DialFormat.number($0, step: 0.1) } ?? "Off"
        case .number(let v): text = DialFormat.number(v, step: 0.1)
        default: text = value.compactDescription
        }
        return Button {
            numberText = value.doubleValue.map { DialFormat.number($0, step: 0.1) } ?? ""
            showNumberEntry = true
        } label: {
            SettingRow(title: spec.title, subtitle: compact ? nil : (spec.note.isEmpty ? nil : spec.note), chevron: false) {
                HStack(spacing: 6) {
                    if sensitivity != 0 { SensitivityBadge(kcal: sensitivity, key: spec.key) }
                    Text(text).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    if !spec.unit.isEmpty && text != "Off" {
                        Text(spec.unit).font(Theme.body()).foregroundStyle(Theme.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .alert(spec.title, isPresented: $showNumberEntry) {
            TextField(spec.unit.isEmpty ? "Value" : spec.unit, text: $numberText).keyboardType(.decimalPad)
            Button("Save") {
                if let v = Double(numberText.replacingOccurrences(of: ",", with: "")) {
                    if case .optionalNumber = spec.defaultValue { model.setDial(spec.key, .optionalNumber(v)) } else { model.setDial(spec.key, .number(v)) }
                }
            }
            if allowsOff {
                Button("Turn off") { model.setDial(spec.key, .optionalNumber(nil)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(spec.note)
        }
    }

    // MARK: Date

    private func dateBody(allowsNone: Bool) -> some View {
        var current: Date? = nil
        if case .date(let dv) = value { current = dv }
        return SettingRow(title: spec.title, subtitle: compact ? nil : (spec.note.isEmpty ? nil : spec.note), chevron: false) {
            HStack(spacing: 8) {
                DatePicker("", selection: Binding(get: { current ?? Date() }, set: { model.setDial(spec.key, .date($0)) }), displayedComponents: .date)
                    .labelsHidden()
                if allowsNone && current != nil {
                    Button { model.setDial(spec.key, .date(nil)) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Weekday set

    private var weekdaySetBody: some View {
        let selected: [Int] = { if case .intList(let l) = value { return l } else { return [] } }()
        let names = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(alignment: .leading, spacing: 10) {
            Text(spec.title).font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let on = selected.contains(day)
                    Button {
                        var set = Set(selected)
                        if on { set.remove(day) } else { set.insert(day) }
                        model.setDial(spec.key, .intList(set.sorted()))
                    } label: {
                        Text(names[day - 1])
                            .font(Theme.bodySmall(.semibold))
                            .foregroundStyle(on ? .white : Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(on ? Theme.ink : Theme.pill))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !spec.note.isEmpty { Text(spec.note).font(Theme.caption()).foregroundStyle(Theme.secondary) }
        }
    }

    // MARK: Weekday offsets

    private var weekdayOffsetsBody: some View {
        let offsets: [Double] = { if case .numberList(let l) = value, l.count == 7 { return l } else { return Array(repeating: 0, count: 7) } }()
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(spec.title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                if sensitivity != 0 { SensitivityBadge(kcal: sensitivity, key: spec.key) }
            }
            ForEach(0..<7, id: \.self) { i in
                HStack {
                    Text(names[i]).font(Theme.body()).foregroundStyle(Theme.secondary).frame(width: 44, alignment: .leading)
                    Spacer()
                    Stepper(value: Binding(get: { offsets[i] }, set: { new in
                        var copy = offsets
                        copy[i] = new
                        model.setDial(spec.key, .numberList(copy))
                    }), in: -1000...1000, step: 50) {
                        Text("\(Fmt.signed(offsets[i], 0)) kcal").font(Theme.body(.semibold)).monospacedDigit().foregroundStyle(offsets[i] == 0 ? Theme.secondary : Theme.ink)
                    }
                    .frame(width: 200)
                }
            }
            noteRow
        }
    }
}

struct SensitivityBadge: View {
    @Environment(AppModel.self) private var model
    let kcal: Double
    let key: DialKey

    var body: some View {
        Button {
            model.showDetail(.sensitivity(key))
        } label: {
            Text("\(Fmt.signed(kcal, 0)) kcal")
                .font(Theme.bodySmall(.semibold)).monospacedDigit()
                .foregroundStyle(Theme.accent)
                .underline(true, pattern: .dot, color: Theme.accent)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Theme.accentTint))
        }
        .buttonStyle(.plain)
    }
}

enum DialFormat {
    /// Formats a dial value with as many decimals as its step needs, trailing zeros trimmed.
    static func number(_ v: Double, step: Double) -> String {
        var digits = 0
        var s = step
        while s > 0, s < 0.999, digits < 6 {
            s *= 10
            digits += 1
        }
        var text = String(format: "%.\(digits)f", v)
        if digits > 0 {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        if abs(v) >= 1000, digits == 0 { return Fmt.int(v) }
        return text
    }
}

// MARK: - Presets

struct PresetsBlock: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \PresetRecord.created) private var presets: [PresetRecord]
    @State private var showSave = false
    @State private var name = ""
    @State private var showImporter = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Presets").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Save current") {
                    name = model.activePresetName ?? ""
                    showSave = true
                }
                .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
            }
            if presets.isEmpty {
                Text("Save the whole set of dials under a name, like “Offseason” or “Prep, 12 out”, and switch in one tap.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets) { p in
                            PillChip(title: p.name, active: model.activePresetName == p.name) {
                                model.applyPreset(p)
                            }
                            .contextMenu {
                                Button("Export JSON") { export(p) }
                                Button("Delete", role: .destructive) { model.deletePreset(p) }
                            }
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                Button("Import JSON") { showImporter = true }
                    .font(Theme.caption()).foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 18)
        .alert("Save preset", isPresented: $showSave) {
            TextField("Name", text: $name)
            Button("Save") {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { model.savePreset(named: n) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            if let preset = try? Dials.jsonDecoder.decode(DialsPreset.self, from: data) {
                model.context.insert(PresetRecord(name: preset.name, dials: preset.dials))
                model.showToast("Imported “\(preset.name)”")
            } else if let dials = try? Dials.decode(json: data) {
                model.context.insert(PresetRecord(name: url.deletingPathExtension().lastPathComponent, dials: dials))
                model.showToast("Imported preset")
            } else {
                model.showToast("That file isn't a Tare preset")
            }
        }
        .sheet(item: Binding(get: { exportURL.map(ShareItem.init) }, set: { exportURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func export(_ p: PresetRecord) {
        guard let dials = p.dials else { return }
        let preset = DialsPreset(id: p.id, name: p.name, created: p.created, dials: dials)
        guard let data = try? Dials.jsonEncoder.encode(preset) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(p.name).tare-preset.json")
        try? data.write(to: url)
        exportURL = url
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Change log

struct ChangeLogBlock: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \DialChange.date, order: .reverse) private var changes: [DialChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Change log").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
            if changes.isEmpty {
                Text("Every dial change is dated here and marked on the Trend chart.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary)
            }
            ForEach(changes.prefix(30)) { c in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title).font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                        Text("\(c.oldDescription) → \(c.newDescription)").font(Theme.caption()).monospacedDigit().foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Fmt.shortDate(c.date)).font(Theme.caption()).foregroundStyle(Theme.secondary)
                        Text(sourceLabel(c.source)).font(Theme.captionSmall()).foregroundStyle(Theme.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 18)
    }

    private func sourceLabel(_ s: DialChangeSource) -> String {
        switch s {
        case .user: return "you"
        case .coach: return "coach"
        case .preset: return "preset"
        case .onboarding: return "setup"
        case .undo: return "undo"
        }
    }
}
