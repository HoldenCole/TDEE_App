import SwiftUI
import TareEngine

/// First launch: Health access, then body basics from Health (editable), then the phase.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var sex: Sex = .male
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var heightInches: Double = 70
    @State private var bodyFat: String = ""
    @State private var phase: Phase = .leanBulk
    @State private var requesting = false
    @State private var healthDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)
            switch step {
            case 0: welcome
            case 1: health
            case 2: profile
            default: phasePick
            }
            Spacer()
        }
        .padding(.horizontal, Theme.sideMargin)
        .background(Theme.surface)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tare").font(.system(size: 44, weight: .bold)).tracking(-1.5).foregroundStyle(Theme.ink)
            Text("To tare a scale is to zero it so you read the true weight. Tare does that for your metabolism: it starts from formulas, then recalibrates to what your body actually does.")
                .font(.system(size: 17)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Every constant in the math is a dial you can change. Nothing leaves your phone.")
                .font(.system(size: 17)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            InkButton(title: "Get started") { withAnimation { step = 1 } }.padding(.top, 20)
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Step 1 of 3")
            Text("Connect Apple Health").titleStyle()
            Text("Tare reads weigh-ins, food, steps, active energy and workouts from Health. It only reads, never writes. Most nutrition, workout, wearable and scale apps already sync there.")
                .font(.system(size: 17)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            if !HealthSync.isAvailable {
                Text("Health isn't available on this device. You can log by hand or import a spreadsheet.").font(Theme.body()).foregroundStyle(Theme.behind)
            }
            InkButton(title: healthDone ? "Connected" : (requesting ? "Asking…" : "Allow Health access")) {
                Task { await connectHealth() }
            }
            .disabled(requesting || healthDone)
            .padding(.top, 10)
            Button(healthDone ? "Continue" : "Skip for now") {
                withAnimation { step = 2 }
            }
            .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
        }
    }

    private func connectHealth() async {
        requesting = true
        defer { requesting = false }
        do {
            try await model.health.requestAuthorization()
            let p = await model.health.profile()
            if let s = p.sex { sex = s }
            if let b = p.birthDate { birthDate = b }
            if let h = p.heightCm { heightInches = Units.inches(fromCm: h) }
            healthDone = true
            Task { await model.syncHealth(days: 60) }
            withAnimation { step = 2 }
        } catch {
            healthDone = false
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Step 2 of 3")
            Text("Body basics").titleStyle()
            Text("The BMR formulas need these. Health filled in what it had; fix anything that's wrong.")
                .font(.system(size: 17)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Sex", selection: $sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Date of birth").font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Height").font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Fmt.heightFeetInches(cm: Units.cm(fromInches: heightInches))).font(Theme.body(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                TareSlider(value: $heightInches, range: 48...84, step: 0.5)
            }
            HStack {
                Text("Body fat, if you know it").font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                TextField("%", text: $bodyFat).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                    .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Theme.pill))
            }
            InkButton(title: "Continue") { withAnimation { step = 3 } }.padding(.top, 10)
        }
    }

    private var phasePick: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Step 3 of 3")
            Text("What are you doing right now?").titleStyle()
            VStack(spacing: 8) {
                ForEach(Phase.allCases, id: \.self) { p in
                    Button {
                        phase = p
                    } label: {
                        HStack {
                            Text(p.title).font(Theme.body(.semibold)).foregroundStyle(phase == p ? .white : Theme.ink)
                            Spacer()
                            Text("\(Fmt.signed(p.defaultRatePercent, 2))% / wk").font(Theme.body()).foregroundStyle(phase == p ? .white.opacity(0.8) : Theme.secondary)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(phase == p ? Theme.ink : Theme.pill))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("You can change this and the rate on the Plan tab any time.").font(Theme.caption()).foregroundStyle(Theme.tertiary)
            InkButton(title: "Open Tare") { finish() }.padding(.top, 10)
        }
    }

    private func finish() {
        model.setDial(.sex, .choice(sex.rawValue), source: .onboarding, log: false)
        model.setDial(.birthDate, .date(birthDate), source: .onboarding, log: false)
        model.setDial(.heightCm, .optionalNumber(Units.cm(fromInches: heightInches)), source: .onboarding, log: false)
        if let bf = Double(bodyFat), bf > 0 {
            model.setDial(.bodyFatPercentManual, .optionalNumber(bf), source: .onboarding, log: false)
        }
        model.setDial(.phase, .choice(phase.rawValue), source: .onboarding, log: false)
        model.setDial(.ratePercentPerWeek, .number(phase.defaultRatePercent), source: .onboarding, log: false)
        model.completeOnboarding()
        model.startHealthBackgroundDelivery()
    }
}
