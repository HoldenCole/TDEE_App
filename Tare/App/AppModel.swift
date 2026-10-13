import Foundation
import SwiftData
import SwiftUI
import WidgetKit
import TareEngine

enum AppTab: Hashable {
    case today, trend, progress, plan, dials
}

/// The one observable store. Screens read `snapshot` and `dials`; every change goes through here
/// so it is persisted, logged and recomputed in one place.
@Observable
@MainActor
final class AppModel {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    // Engine inputs and output
    private(set) var dials: Dials
    private(set) var log: [DayInput] = []
    private(set) var liftSets: [LiftSetInput] = []
    private(set) var muscleMap = MuscleMap()
    private(set) var snapshot: EngineSnapshot
    private(set) var openRecommendation: CoachRecommendation?
    private(set) var openRecommendationRecordID: UUID?

    // Navigation and transient UI
    var selectedTab: AppTab = .today
    var detailNumber: NumberID?
    var dialsGroupFilter: DialGroup?
    var dialsSearch: String = ""
    var toast: Toast?
    var onboarded: Bool
    var showCoachScreen = false
    var progressUnlocked = false

    // Services
    let health = HealthSync()
    private(set) var isSyncingHealth = false
    private var healthResyncRequested = false
    private(set) var lastError: String?

    init(container: ModelContainer) {
        let loaded = AppState.loadDials()
        self.container = container
        self.dials = loaded
        self.onboarded = AppState.onboarded
        self.snapshot = Engine.compute(log: [], dials: loaded)
        _ = AppState.firstLaunch
        reloadAll()
        if DemoData.requestedAtLaunch {
            DemoData.seed(into: self)
            completeOnboarding()
        }
        if CommandLine.arguments.contains("-TareSkipOnboarding") {
            completeOnboarding()
        }
    }

    // MARK: Loading and recompute

    func reloadAll() {
        let dayDescriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.date)])
        log = ((try? context.fetch(dayDescriptor)) ?? []).map(\.asInput)
        let setDescriptor = FetchDescriptor<LiftSet>(sortBy: [SortDescriptor(\.date)])
        liftSets = ((try? context.fetch(setDescriptor)) ?? []).map(\.asInput)
        var map = MuscleMap()
        for entry in (try? context.fetch(FetchDescriptor<ExerciseMapEntry>())) ?? [] {
            if let m = entry.muscles { map.overrides[entry.exercise] = m }
        }
        muscleMap = map
        reloadOpenRecommendation()
        recompute()
    }

    func recompute() {
        snapshot = Engine.compute(log: log, dials: dials)
        refreshWidget()
    }

    var isFirstWeek: Bool {
        Calendar.current.days(from: AppState.firstLaunch, to: Date()) < 7
    }

    // MARK: Detail sheet and navigation

    func showDetail(_ number: NumberID) {
        detailNumber = number
    }

    func tuneDials(group: DialGroup) {
        detailNumber = nil
        dialsGroupFilter = group
        selectedTab = .dials
    }

    func showToast(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        toast = Toast(message: message, actionTitle: actionTitle, action: action)
    }

    // MARK: Dials

    /// Sets one dial. Logs a `DialChange` when the value actually changed.
    @discardableResult
    func setDial(_ key: DialKey, _ value: DialValue, source: DialChangeSource = .user, recommendationID: UUID? = nil, log shouldLog: Bool = true) -> DialChange? {
        let old = dials.value(for: key)
        var updated = dials
        updated.set(value, for: key)
        let new = updated.value(for: key)
        guard new != old else { return nil }
        var phaseWarning: Phase?
        if key == .phase, let phase = value.choiceValue.flatMap(Phase.init(rawValue:)) {
            // Nothing else changes: the rate and every other dial carry over, and the
            // switch is logged so the charts can mark it and shade each phase.
            updated.phaseStartDate = Calendar.current.startOfDay(for: Date())
            let rate = GoalRate.compute(dials: updated, weightLb: snapshot.body.weightUsedLb, today: Date(), calendar: .current).lbPerWeek
            if (phase.isDeficit && rate > 0) || (phase.isSurplus && rate < 0) { phaseWarning = phase }
        }
        dials = updated
        AppState.saveDials(dials)
        var change: DialChange?
        if shouldLog {
            let title = DialCatalog.spec(for: key, in: dials)?.title ?? key.rawValue
            let c = DialChange(key: key, title: title, oldValue: old, newValue: new, source: source, recommendationID: recommendationID)
            context.insert(c)
            change = c
        }
        AppState.activePresetName = nil
        recompute()
        if let phase = phaseWarning, source == .user {
            let suggested = phase.defaultRatePercent
            showToast("Rate is \(dials.ratePercentPerWeek > 0 ? "a surplus" : "a deficit") during a \(phase.title.lowercased())", actionTitle: "Use \(Fmt.signed(suggested, 2))%") { [weak self] in
                self?.setDial(.ratePercentPerWeek, .number(suggested))
            }
        }
        return change
    }

    /// Live edits while dragging: update without logging. Call `commitDial` when the drag ends.
    func previewDial(_ key: DialKey, _ value: DialValue) {
        var updated = dials
        updated.set(value, for: key)
        dials = updated
        snapshot = Engine.compute(log: log, dials: dials)
    }

    func commitDial(_ key: DialKey, from old: DialValue) {
        let new = dials.value(for: key)
        AppState.saveDials(dials)
        guard new != old else { return }
        let title = DialCatalog.spec(for: key, in: dials)?.title ?? key.rawValue
        context.insert(DialChange(key: key, title: title, oldValue: old, newValue: new, source: .user))
        AppState.activePresetName = nil
        refreshWidget()
    }

    func resetDial(_ key: DialKey) {
        guard let spec = DialCatalog.spec(for: key, in: dials) else { return }
        setDial(key, spec.defaultValue)
    }

    /// The "+38 kcal" badge: today's target now versus with this dial at its default.
    func sensitivity(for key: DialKey) -> Double {
        Engine.sensitivityFromDefault(log: log, dials: dials, key: key)
    }

    func replaceDials(_ new: Dials, source: DialChangeSource, keepPhaseStart: Bool = true) {
        var incoming = new
        if keepPhaseStart, incoming.phase == dials.phase {
            incoming.phaseStartDate = dials.phaseStartDate
        }
        // Log each row that changed so the Trend chart can mark the switch.
        let specs = DialCatalog.specs(for: incoming)
        for spec in specs {
            let old = dials.value(for: spec.key)
            let newValue = incoming.value(for: spec.key)
            if old != newValue {
                context.insert(DialChange(key: spec.key, title: spec.title, oldValue: old, newValue: newValue, source: source))
            }
        }
        dials = incoming
        AppState.saveDials(dials)
        recompute()
    }

    // MARK: Presets

    func presets() -> [PresetRecord] {
        (try? context.fetch(FetchDescriptor<PresetRecord>(sortBy: [SortDescriptor(\.created)]))) ?? []
    }

    func savePreset(named name: String) {
        if let existing = presets().first(where: { $0.name == name }) {
            existing.dialsJSON = (try? dials.encodedJSON()) ?? Data()
        } else {
            context.insert(PresetRecord(name: name, dials: dials))
        }
        AppState.activePresetName = name
        showToast("Saved preset “\(name)”")
    }

    func applyPreset(_ preset: PresetRecord) {
        guard let d = preset.dials else { return }
        replaceDials(d, source: .preset)
        AppState.activePresetName = preset.name
        showToast("Switched to “\(preset.name)”")
    }

    func deletePreset(_ preset: PresetRecord) {
        if AppState.activePresetName == preset.name { AppState.activePresetName = nil }
        context.delete(preset)
    }

    var activePresetName: String? { AppState.activePresetName }

    // MARK: Change log

    func dialChanges(limit: Int? = nil) -> [DialChange] {
        var d = FetchDescriptor<DialChange>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let limit { d.fetchLimit = limit }
        return (try? context.fetch(d)) ?? []
    }

    /// Changes the charts mark with a dashed rule: user and coach changes to dials that move
    /// the target. Phase switches are drawn separately, as shaded spans.
    func chartMarkers(from start: Date) -> [DialChange] {
        dialChanges().filter { $0.date >= start && $0.source != .undo && $0.source != .onboarding && $0.dialKey != .phase }
            .filter { DialCatalog.spec(for: $0.dialKey, in: dials)?.affectsTarget ?? true }
    }

    /// Every phase switch, oldest first.
    func phaseChanges() -> [DialChange] {
        dialChanges().filter { $0.dialKey == .phase && $0.source != .undo }.sorted { $0.date < $1.date }
    }

    /// The phase in effect across a date range, split at each switch, so charts can shade
    /// each cut and bulk and draw a line where one became the other.
    func phaseSpans(from start: Date, to end: Date) -> [PhaseSpan] {
        let changes = phaseChanges()
        var current: Phase = changes.first?.oldValue?.choiceValue.flatMap(Phase.init(rawValue:)) ?? dials.phase
        var spans: [PhaseSpan] = []
        var spanStart = start
        for c in changes {
            guard let to = c.newValue?.choiceValue.flatMap(Phase.init(rawValue:)) else { continue }
            if c.date <= start {
                current = to
                continue
            }
            if c.date > end { break }
            spans.append(PhaseSpan(phase: current, start: spanStart, end: c.date, startsWithSwitch: spanStart != start))
            current = to
            spanStart = c.date
        }
        spans.append(PhaseSpan(phase: current, start: spanStart, end: end, startsWithSwitch: spanStart != start))
        return spans
    }

    // MARK: Day records

    func dayRecord(for date: Date, create: Bool) -> DayRecord? {
        let day = Calendar.current.startOfDay(for: date)
        var d = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.date == day })
        d.fetchLimit = 1
        if let existing = try? context.fetch(d).first { return existing }
        guard create else { return nil }
        let r = DayRecord(date: day)
        context.insert(r)
        return r
    }

    /// Merges imported or synced days into the store.
    func upsertDays(_ days: [DayInput], synced: Bool) {
        for input in days {
            guard let record = dayRecord(for: input.date, create: true) else { continue }
            record.merge(input)
            if synced { record.lastSynced = Date() }
        }
        try? context.save()
        reloadAll()
    }

    func setLiftingToday(_ value: Bool?) {
        guard let record = dayRecord(for: Date(), create: true) else { return }
        record.liftingOverride = value
        try? context.save()
        reloadAll()
    }

    func setFoodLogComplete(_ complete: Bool, on date: Date) {
        guard let record = dayRecord(for: date, create: true) else { return }
        record.foodLogComplete = complete
        try? context.save()
        reloadAll()
    }

    func logManualWeight(_ lb: Double, on date: Date = Date()) {
        guard let record = dayRecord(for: date, create: true) else { return }
        record.weightLb = lb
        try? context.save()
        reloadAll()
    }

    func logManualIntake(calories: Double?, protein: Double?, carbs: Double?, fat: Double?, on date: Date = Date()) {
        guard let record = dayRecord(for: date, create: true) else { return }
        if let calories { record.calories = calories }
        if let protein { record.proteinG = protein }
        if let carbs { record.carbsG = carbs }
        if let fat { record.fatG = fat }
        try? context.save()
        reloadAll()
    }

    // MARK: Lift sets and muscle tags

    /// Adds sets, skipping any already stored (same date, exercise, set index).
    @discardableResult
    func addLiftSets(_ sets: [LiftSetInput], batchID: String?) -> Int {
        let existing = Set(((try? context.fetch(FetchDescriptor<LiftSet>())) ?? []).map(\.dedupeKey))
        var added = 0
        var seen = existing
        for s in sets {
            let key = LiftSet.dedupeKey(for: s)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            context.insert(LiftSet(input: s, batchID: batchID))
            added += 1
        }
        try? context.save()
        reloadAll()
        return added
    }

    func tagExercise(_ exercise: String, as muscles: ExerciseMuscles, fromSource: Bool = false) {
        let key = MuscleMap.normalize(exercise)
        var d = FetchDescriptor<ExerciseMapEntry>(predicate: #Predicate { $0.exercise == key })
        d.fetchLimit = 1
        if let existing = try? context.fetch(d).first {
            // A tag the user set by hand beats one a source provided.
            let userTagWouldBeOverwritten = !existing.fromSource && fromSource
            if !userTagWouldBeOverwritten {
                existing.primaryRaw = muscles.primary.rawValue
                existing.secondaryRaw = muscles.secondary.map(\.rawValue)
                existing.fromSource = fromSource
            }
        } else {
            context.insert(ExerciseMapEntry(exercise: exercise, muscles: muscles, fromSource: fromSource))
        }
        try? context.save()
        reloadAll()
    }

    var untaggedExercises: [String] { muscleMap.unknownExercises(in: liftSets) }

    // MARK: Health

    /// Pulls the last `days` days from Health. A delivery that lands mid-sync queues one more
    /// pass, so a workout or meal that arrives while we're reading is never missed.
    func syncHealth(days: Int = 60) async {
        guard HealthSync.isAvailable, AppState.healthAuthorized else { return }
        if isSyncingHealth {
            healthResyncRequested = true
            return
        }
        isSyncingHealth = true
        do {
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
            let fetched = try await health.fetchDays(from: start, to: end)
            upsertDays(fetched, synced: true)
            AppState.healthLastSync = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isSyncingHealth = false
        if healthResyncRequested {
            healthResyncRequested = false
            await syncHealth(days: 3)
        }
    }

    /// Called when the app comes to the foreground: Health, then Hevy if a key is set and
    /// the last pull is older than 15 minutes, then the coach.
    func refreshOnForeground() async {
        await syncHealth(days: 7)
        if HevyConnector.hasKey, (AppState.hevyLastSync.map { Date().timeIntervalSince($0) > 15 * 60 } ?? true) {
            _ = try? await HevyConnector.sync(model: self, fullHistory: false)
        }
        runCoachIfDue()
    }

    func startHealthBackgroundDelivery() {
        guard HealthSync.isAvailable, AppState.healthAuthorized else { return }
        health.startBackgroundDelivery { [weak self] in
            Task { @MainActor in
                await self?.syncHealth(days: 3)
                self?.runCoachIfDue()
            }
        }
    }

    // MARK: Coach

    private func reloadOpenRecommendation() {
        let now = Date()
        let descriptor = FetchDescriptor<Recommendation>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let records = (try? context.fetch(descriptor)) ?? []
        if let record = records.first(where: { $0.isActionable(on: now) }), let rec = record.decoded {
            openRecommendation = rec
            openRecommendationRecordID = record.id
        } else {
            openRecommendation = nil
            openRecommendationRecordID = nil
        }
    }

    func recommendationRecord(id: UUID) -> Recommendation? {
        var d = FetchDescriptor<Recommendation>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func allRecommendations() -> [Recommendation] {
        (try? context.fetch(FetchDescriptor<Recommendation>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    func runCoachIfDue() {
        guard Coach.isCheckInDue(lastCheckIn: AppState.lastCheckIn, today: Date(), dials: dials) else { return }
        runCoachNow()
    }

    /// Runs every rule and stores what fires. Called on the check-in day, or by hand from Data sources.
    func runCoachNow() {
        let context = CoachContext(log: log, liftSets: liftSets, muscleMap: muscleMap, previousRateMisses: AppState.rateMisses)
        let report = Coach.evaluate(context: context, dials: dials)
        AppState.rateMisses = report.consecutiveRateMisses
        AppState.lastCheckIn = Date()

        let existing = allRecommendations()
        for rec in report.recommendations {
            // One open recommendation per rule: the new one replaces an older open or snoozed one.
            for old in existing where old.rule == rec.rule && (old.status == .open || old.status == .snoozed) {
                old.status = .dismissed
                old.resolvedAt = Date()
            }
            let record = Recommendation(recommendation: rec)
            self.context.insert(record)
            if dials.coachAutoApply, rec.hasProposal, rec.rule == .rateOffTarget {
                accept(recordID: record.id, kcalOverride: nil, silent: true)
            }
        }
        try? self.context.save()
        reloadOpenRecommendation()
        recompute()
    }

    /// Applies the recommendation's dial changes, logs them, and offers a 10-second undo.
    func accept(recordID: UUID, kcalOverride: Double?, silent: Bool = false) {
        guard let record = recommendationRecord(id: recordID), var rec = record.decoded else { return }
        var proposals = rec.proposals
        if let kcal = kcalOverride, kcal != rec.kcalChange, rec.rule == .rateOffTarget || rec.rule == .strengthDropping {
            // Edited amount: rebuild the rate proposal for the new kcal change.
            let goal = snapshot.targets.goalRate
            let newLb = goal.lbPerWeek + kcal * 7 / dials.kcalPerLb
            if let (key, value) = GoalRate.dialValue(forLbPerWeek: newLb, dials: dials, weightLb: snapshot.body.weightUsedLb) {
                proposals = [DialProposal(key: key, oldValue: dials.value(for: key), newValue: value)]
            }
            rec.kcalChange = kcal
        }
        var changes: [DialChange] = []
        for p in proposals {
            if let c = setDial(p.key, p.newValue, source: .coach, recommendationID: rec.id) { changes.append(c) }
        }
        record.status = .accepted
        record.resolvedAt = Date()
        record.appliedKcalChange = rec.kcalChange
        try? context.save()
        reloadOpenRecommendation()
        if !silent {
            let message = rec.hasProposal ? "Applied: \(rec.headline)" : "Noted"
            showToast(message, actionTitle: changes.isEmpty ? nil : "Undo") { [weak self] in
                self?.undo(changes: changes, recordID: recordID)
            }
        }
    }

    func snooze(recordID: UUID, days: Int = 7) {
        guard let record = recommendationRecord(id: recordID) else { return }
        record.status = .snoozed
        record.snoozedUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
        try? context.save()
        reloadOpenRecommendation()
    }

    func dismiss(recordID: UUID) {
        guard let record = recommendationRecord(id: recordID) else { return }
        record.status = .dismissed
        record.resolvedAt = Date()
        try? context.save()
        reloadOpenRecommendation()
    }

    private func undo(changes: [DialChange], recordID: UUID) {
        for c in changes.reversed() {
            if let old = c.oldValue {
                setDial(c.dialKey, old, source: .undo, recommendationID: c.recommendationID)
            }
        }
        if let record = recommendationRecord(id: recordID) {
            record.status = .open
            record.resolvedAt = nil
            record.appliedKcalChange = nil
        }
        try? context.save()
        reloadOpenRecommendation()
    }

    // MARK: Widget

    func refreshWidget() {
        let s = snapshot
        WidgetSnapshot(
            date: Date(),
            targetCalories: s.today.calories,
            eatenCalories: s.eatenCalories,
            isTrainingDay: s.isTrainingDay,
            proteinEaten: s.todayLog?.proteinG ?? 0,
            proteinTarget: s.today.proteinG
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Onboarding

    func completeOnboarding() {
        onboarded = true
        AppState.onboarded = true
    }
}
