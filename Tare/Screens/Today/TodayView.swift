import SwiftUI
import TareEngine

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showLog = false

    private var s: EngineSnapshot { model.snapshot }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Screen {
                ScreenHeader(kicker: Fmt.longDate(Date()), title: "Today") {
                    TrainingDayPill()
                }
                .padding(.bottom, 22)

                if let rec = model.openRecommendation, let id = model.openRecommendationRecordID {
                    CoachCard(recommendation: rec, recordID: id) {
                        model.showCoachScreen = true
                    }
                    .padding(.bottom, 28)
                }

                remaining
                    .padding(.bottom, 20)

                macros
                    .padding(.bottom, 24)

                Hairline()
                    .padding(.bottom, 20)

                stats
                    .padding(.bottom, 20)

                if model.isFirstWeek {
                    Text("Any dotted number opens its chart.")
                        .font(Theme.body()).foregroundStyle(Theme.tertiary)
                        .padding(.bottom, 12)
                }

                if !s.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(s.warnings, id: \.self) { w in
                            Text(w).font(Theme.caption()).foregroundStyle(Theme.behind)
                        }
                    }
                    .padding(.top, 8)
                }

                HStack {
                    PillButton(title: "Log today") { showLog = true }.accessibilityIdentifier("today.log")
                    Spacer()
                }
                .padding(.top, 20)
            }
            .refreshable { await model.refreshOnForeground() }
            .navigationDestination(isPresented: $model.showCoachScreen) {
                if let rec = model.openRecommendation, let id = model.openRecommendationRecordID {
                    CoachView(recommendation: rec, recordID: id)
                } else {
                    CoachHistoryView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLog) {
                LogDaySheet()
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(Theme.sheetRadius)
            }
        }
    }

    private var remaining: some View {
        VStack(spacing: 10) {
            Eyebrow("Remaining today")
            DottedNumber(text: Fmt.int(s.remainingCalories), number: .remaining, font: Theme.hero(), tracking: -72 * 0.04, dotted: false)
            HStack(spacing: 4) {
                Text("of").font(.system(size: 20)).foregroundStyle(Theme.secondary)
                DottedNumber(text: Fmt.int(s.today.calories), number: .target, font: .system(size: 20, weight: .semibold))
                Text("kcal · \(Fmt.int(s.eatenCalories)) eaten").font(.system(size: 20)).foregroundStyle(Theme.secondary)
            }
            BarView(fraction: s.today.calories > 0 ? s.eatenCalories / s.today.calories : 0, height: 6)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var macros: some View {
        HStack(alignment: .top, spacing: 20) {
            MacroColumn(name: "Protein", eaten: s.todayLog?.proteinG ?? 0, target: s.today.proteinG, number: .protein)
            MacroColumn(name: "Carbs", eaten: s.todayLog?.carbsG ?? 0, target: s.today.carbsG, number: .carbs)
            MacroColumn(name: "Fat", eaten: s.todayLog?.fatG ?? 0, target: s.today.fatG, number: .fat)
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            StatCell(label: "Weight",
                     value: AnyView(DottedNumber(text: s.body.latestWeighInLb.map(Fmt.lb) ?? "—", number: .weight)),
                     caption: s.body.trendWeightLb.map { "trend \(Fmt.lb($0))" } ?? "no weigh-ins")
            VerticalHairline().padding(.horizontal, 14)
            StatCell(label: "Steps",
                     value: AnyView(DottedNumber(text: s.todayLog?.steps.map { Fmt.int($0) } ?? "—", number: .steps)),
                     caption: "avg \(Fmt.int(s.activity.stepsPerDay))")
            VerticalHairline().padding(.horizontal, 14)
            StatCell(label: "Maintenance",
                     value: AnyView(DottedNumber(text: Fmt.int(s.maintenance), number: .maintenance)),
                     caption: "\(Fmt.int(s.targets.trustPercent))% from data")
        }
    }
}

struct MacroColumn: View {
    let name: String
    let eaten: Double
    let target: Double
    let number: NumberID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(name).font(Theme.body(.semibold)).foregroundStyle(Theme.ink).lineLimit(1).fixedSize()
                Spacer(minLength: 2)
                DottedNumber(text: "\(Fmt.int(eaten)) / \(Fmt.int(target))", number: number, font: Theme.captionSmall(), color: Theme.secondary)
                    .minimumScaleFactor(0.8)
            }
            BarView(fraction: target > 0 ? eaten / target : 0, height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

/// "Training day" in accent on tint once a strength workout appears; tap to toggle for the day.
struct TrainingDayPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let training = model.snapshot.isTrainingDay
        Button {
            model.setLiftingToday(!training)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(training ? Theme.accent : Theme.secondary).frame(width: 7, height: 7)
                Text(training ? "Training day" : "Rest day")
                    .font(Theme.body(.semibold))
                    .foregroundStyle(training ? Theme.accent : Theme.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(training ? Theme.accentTint : Theme.pill))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Use automatic detection") { model.setLiftingToday(nil) }
        }
    }
}

struct CoachCard: View {
    @Environment(AppModel.self) private var model
    let recommendation: CoachRecommendation
    let recordID: UUID
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkle").font(.system(size: 13, weight: .semibold))
                Text("Coach · \(Format.weekdayName(model.dials.coachCheckInWeekday, calendar: .current)) check-in")
                    .font(Theme.eyebrow()).textCase(.uppercase).tracking(1.2)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            Text(recommendation.headline)
                .font(.system(size: 24, weight: .bold)).tracking(-0.5)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(recommendation.reason)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    model.accept(recordID: recordID, kcalOverride: nil)
                } label: {
                    Text(recommendation.hasProposal ? "Accept" : "Got it")
                        .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(.white))
                }
                .buttonStyle(.plain)
                Button {
                    model.snooze(recordID: recordID)
                } label: {
                    Text("Later")
                        .font(Theme.body(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.coachGradient))
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .onTapGesture { open() }
        .accessibilityIdentifier("coachCard")
    }
}

/// Manual entry for days Health doesn't cover, plus the incomplete-log flag.
struct LogDaySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var weight = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var complete = true

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                Section("Weight") {
                    TextField("lb", text: $weight).keyboardType(.decimalPad)
                }
                Section("Food") {
                    TextField("Calories", text: $calories).keyboardType(.numberPad)
                    TextField("Protein g", text: $protein).keyboardType(.numberPad)
                    TextField("Carbs g", text: $carbs).keyboardType(.numberPad)
                    TextField("Fat g", text: $fat).keyboardType(.numberPad)
                    Toggle("Food log complete", isOn: $complete)
                }
                Section {
                    Text("Health is the main source. Use this for days you weighed or ate without logging to Health, or to mark a day as incompletely logged so it stays out of the observed TDEE.")
                        .font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
            }
            .navigationTitle("Log a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: prefill)
            .onChange(of: date) { _, _ in prefill() }
        }
    }

    private func prefill() {
        guard let r = model.dayRecord(for: date, create: false) else {
            weight = ""; calories = ""; protein = ""; carbs = ""; fat = ""; complete = true
            return
        }
        weight = r.weightLb.map { Fmt.dec($0, 1) } ?? ""
        calories = r.calories.map { Fmt.int($0) } ?? ""
        protein = r.proteinG.map { Fmt.int($0) } ?? ""
        carbs = r.carbsG.map { Fmt.int($0) } ?? ""
        fat = r.fatG.map { Fmt.int($0) } ?? ""
        complete = r.foodLogComplete
    }

    private func save() {
        func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) }
        if let w = num(weight) { model.logManualWeight(w, on: date) }
        model.logManualIntake(calories: num(calories), protein: num(protein), carbs: num(carbs), fat: num(fat), on: date)
        model.setFoodLogComplete(complete, on: date)
        dismiss()
    }
}
