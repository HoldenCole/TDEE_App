import SwiftUI
import TareEngine

struct PlanView: View {
    @Environment(AppModel.self) private var model
    @State private var showSavePreset = false
    @State private var presetName = ""
    @State private var dragStart: DialValue?
    @State private var showDietBreak = false
    @State private var dietBreakWeeks = 1

    private var s: EngineSnapshot { model.snapshot }
    private var d: Dials { model.dials }

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: model.activePresetName.map { "Preset · \($0)" } ?? "No preset", title: "Plan") {
                    PillButton(title: "Save preset") {
                        presetName = model.activePresetName ?? ""
                        showSavePreset = true
                    }
                }
                .padding(.bottom, 24)

                phaseChips
                    .padding(.bottom, 26)

                rateSection
                    .padding(.bottom, 24)

                Hairline()

                settingRows

                Hairline()
                    .padding(.bottom, 22)

                targetsTable
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Save preset", isPresented: $showSavePreset) {
                TextField("Name, e.g. Offseason", text: $presetName)
                Button("Save") {
                    let name = presetName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { model.savePreset(named: name) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saves every dial under this name. Switch between presets on the Dials tab.")
            }
        }
    }

    private var phaseChips: some View {
        HStack(spacing: 6) {
            ForEach(Phase.allCases, id: \.self) { phase in
                PillChip(title: phase.title, active: d.phase == phase) {
                    model.setDial(.phase, .choice(phase.rawValue))
                }
            }
        }
    }

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Rate")
            let goal = s.targets.goalRate
            let kcal = goal.dailyKcal
            let kcalText = kcal >= 0 ? "\(Fmt.int(kcal)) kcal surplus" : "\(Fmt.int(-kcal)) kcal deficit"
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                switch d.rateMode {
                case .percentPerWeek:
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Fmt.signed(d.ratePercentPerWeek, 2)).largeStyle(52)
                        Text("%").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                    Text("per week · \(Fmt.signed(goal.lbPerWeek, 2)) lb · \(kcalText)")
                        .font(.system(size: 18)).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .lbPerWeek:
                    Text(Fmt.signed(d.rateLbPerWeek, 2)).largeStyle(52)
                    Text("lb per week · \(Fmt.signed(goal.percentPerWeek, 2))% · \(kcalText)")
                        .font(.system(size: 18)).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .fixedKcal:
                    Text(Fmt.signed(d.fixedKcalOffset, 0)).largeStyle(52)
                    Text("kcal per day · \(Fmt.signed(goal.lbPerWeek, 2)) lb/wk · \(Fmt.signed(goal.percentPerWeek, 2))%")
                        .font(.system(size: 18)).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .goalWeightByDate:
                    Text(Fmt.signed(goal.lbPerWeek, 2)).largeStyle(52)
                    Text("lb per week to reach \(d.goalWeightLb.map { Fmt.int($0) } ?? "—") lb by \(d.goalDate.map(Fmt.mediumDate) ?? "—")")
                        .font(.system(size: 18)).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch d.rateMode {
            case .percentPerWeek:
                rateSlider(key: .ratePercentPerWeek, value: d.ratePercentPerWeek, range: -1.5...1.0, step: 0.05)
            case .lbPerWeek:
                rateSlider(key: .rateLbPerWeek, value: d.rateLbPerWeek, range: -3...2, step: 0.1)
            case .fixedKcal:
                rateSlider(key: .fixedKcalOffset, value: d.fixedKcalOffset, range: -1000...1000, step: 10)
            case .goalWeightByDate:
                Button("Set the goal weight and date in Dials") { model.tuneDials(group: .goal) }
                    .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
            }

            Text(rateCaption)
                .font(Theme.body()).foregroundStyle(Theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func rateSlider(key: DialKey, value: Double, range: ClosedRange<Double>, step: Double) -> some View {
        TareSlider(
            value: Binding(get: { value }, set: { model.previewDial(key, .number($0)) }),
            range: range,
            step: step,
            tint: Theme.accent
        ) { editing in
            if editing, dragStart == nil { dragStart = d.value(for: key) }
            if !editing, let start = dragStart {
                model.commitDial(key, from: start)
                dragStart = nil
            }
        }
        .padding(.top, 8)
    }

    private var rateCaption: String {
        let r = d.phase.usualRange
        switch d.phase {
        case .cut: return "Most lifters keep fat loss between \(Fmt.dec(abs(r.upperBound), 2)) and \(Fmt.dec(abs(r.lowerBound), 2))% per week. Faster costs muscle and strength."
        case .recomp: return "A recomp sits at or just under maintenance, 0 to −0.25% per week, with protein high."
        case .maintain: return "Maintenance holds weight within ±0.1% per week. Use it between phases."
        case .leanBulk: return "Intermediate lifters usually gain best between \(Fmt.dec(r.lowerBound, 2)) and \(Fmt.dec(r.upperBound, 1))% per week. Faster mostly adds fat."
        case .bulk: return "A full bulk runs \(Fmt.dec(r.lowerBound, 1)) to \(Fmt.dec(r.upperBound, 1))% per week. Expect more fat with the muscle."
        }
    }

    private var settingRows: some View {
        VStack(spacing: 0) {
            let gap = s.targets.cyclingGap
            let lift = s.targets.liftDaysPerWeek
            let up = gap * (7 - lift) / 7
            let down = gap * lift / 7
            SettingRow(title: "Calorie cycling", subtitle: d.cyclingEnabled ? "\(Fmt.signed(up, 0)) on lifting days, \(Fmt.signed(-down, 0)) on rest days" : "Same target every day", chevron: false) {
                Toggle("", isOn: Binding(get: { d.cyclingEnabled }, set: { model.setDial(.cyclingEnabled, .bool($0)) }))
                    .labelsHidden()
                    .tint(Theme.ink)
            }
            .onTapGesture { model.tuneDials(group: .cycling) }
            Hairline()
            SettingRow(title: "Protein", chevron: false) {
                valueText("\(Fmt.dec(d.proteinGramsPerLb, 2)) g/lb", bold: "\(Fmt.int(s.targets.weeklyAverage.proteinG)) g")
            }
            .onTapGesture { model.tuneDials(group: .macros) }
            Hairline()
            SettingRow(title: d.fatMode == .gramsPerLb ? "Fat floor" : "Fat share", chevron: false) {
                valueText(d.fatMode == .gramsPerLb ? "\(Fmt.dec(d.fatGramsPerLb, 2)) g/lb" : "\(Fmt.int(d.fatPercentOfCalories))% kcal", bold: "\(Fmt.int(s.targets.weeklyAverage.fatG)) g")
            }
            .onTapGesture { model.tuneDials(group: .macros) }
            Hairline()
            SettingRow(title: "Diet break", subtitle: s.targets.goalRate.isDietBreak ? "Rate held at 0 until it ends" : nil) {
                Text(model.dietBreakStatus).font(.system(size: 17, weight: .semibold)).foregroundStyle(s.targets.goalRate.isDietBreak ? Theme.good : Theme.secondary)
            }
            .onTapGesture {
                dietBreakWeeks = max(1, d.dietBreakWeeks)
                showDietBreak = true
            }
            .accessibilityIdentifier("plan.dietBreak")
            Hairline()
            SettingRow(title: "Refeed days", subtitle: "Extra calories on a weekday") {
                Text(model.refeedSummary).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.secondary)
            }
            .onTapGesture { model.tuneDials(group: .cycling) }
        }
        .confirmationDialog("Diet break", isPresented: $showDietBreak, titleVisibility: .visible) {
            ForEach([1, 2, 3], id: \.self) { w in
                Button("Start \(w) week\(w == 1 ? "" : "s") at maintenance today") { model.startDietBreak(weeks: w) }
            }
            if d.dietBreakStartDate != nil {
                Button("Clear the diet break", role: .destructive) { model.endDietBreak() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The rate goes to zero for the break and comes back on its own. The Trend chart marks it.")
        }
    }

    private func valueText(_ light: String, bold: String) -> some View {
        HStack(spacing: 4) {
            Text(light).font(.system(size: 18)).foregroundStyle(Theme.secondary)
            Text("·").font(.system(size: 18)).foregroundStyle(Theme.secondary)
            Text(bold).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    private var targetsTable: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Daily targets")
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 18) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    ForEach(["kcal", "P", "C", "F"], id: \.self) { h in
                        Text(h).font(Theme.caption()).foregroundStyle(Theme.tertiary)
                    }
                }
                targetRow("Training", s.targets.training, color: Theme.accent, number: .target)
                targetRow("Rest", s.targets.rest, color: Theme.ink, number: .target)
                targetRow("Weekly avg", s.targets.weeklyAverage, color: Theme.secondary, number: nil)
            }
            if s.targets.training.carbsBelowFloor || s.targets.rest.carbsBelowFloor {
                Text("Carbs fall below your \(Fmt.int(d.carbFloorGrams)) g floor.").font(Theme.caption()).foregroundStyle(Theme.behind)
            }
            if s.targets.hitFloor || s.targets.hitCeiling {
                Text(s.targets.hitFloor ? "Held at your calorie floor." : "Held at your calorie ceiling.").font(Theme.caption()).foregroundStyle(Theme.behind)
            }
        }
    }

    private func targetRow(_ name: String, _ t: DayTargets, color: Color, number: NumberID?) -> some View {
        GridRow {
            Text(name).font(.system(size: 18, weight: .semibold)).foregroundStyle(color).gridColumnAlignment(.leading)
            if let number {
                DottedNumber(text: Fmt.int(t.calories), number: number, font: .system(size: 20, weight: .bold), color: color)
            } else {
                Text(Fmt.int(t.calories)).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(color)
            }
            Text(Fmt.int(t.proteinG)).font(.system(size: 20)).monospacedDigit().foregroundStyle(color)
            Text(Fmt.int(t.carbsG)).font(.system(size: 20)).monospacedDigit().foregroundStyle(color)
            Text(Fmt.int(t.fatG)).font(.system(size: 20)).monospacedDigit().foregroundStyle(color)
        }
    }
}
