import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import TareEngine
import TareFiles

/// Health status, the Hevy connection, spreadsheet import and export.
struct DataSourcesView: View {
    @Environment(AppModel.self) private var model
    @State private var hevyKey = Keychain.get(Keychain.hevyKey) ?? ""
    @State private var hevyStatus: String?
    @State private var syncingHevy = false
    @State private var showImporter = false
    @State private var candidate: ImportCandidate?
    @State private var shareURL: URL?
    @State private var errorText: String?
    @State private var confirmWipe = false

    var body: some View {
        Screen {
            ScreenHeader(kicker: "Where the numbers come from", title: "Data sources").padding(.bottom, 20)

            section("Apple Health") {
                Text(healthStatus).font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PillButton(title: AppState.healthAuthorized ? "Sync 60 days" : "Connect") {
                        Task {
                            if !AppState.healthAuthorized { try? await model.health.requestAuthorization() }
                            await model.syncHealth(days: 60)
                            model.startHealthBackgroundDelivery()
                        }
                    }
                    if model.isSyncingHealth { ProgressView() }
                }
                if let e = model.lastError { Text(e).font(Theme.caption()).foregroundStyle(Theme.behind) }
            }

            section("Hevy") {
                Text("Sets, reps and weight come from the Hevy API (needs Hevy Pro) or a CSV export. Paste your key from Hevy → Settings → Developer.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                SecureField("API key", text: $hevyKey)
                    .font(Theme.body())
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.pill))
                    .onChange(of: hevyKey) { _, new in Keychain.set(new.trimmingCharacters(in: .whitespacesAndNewlines), for: Keychain.hevyKey) }
                HStack(spacing: 10) {
                    PillButton(title: syncingHevy ? "Syncing…" : "Sync Hevy") { Task { await syncHevy(full: false) } }
                        .disabled(syncingHevy || hevyKey.isEmpty)
                    Button("Full history") { Task { await syncHevy(full: true) } }
                        .font(Theme.body(.semibold)).foregroundStyle(Theme.accent).disabled(syncingHevy || hevyKey.isEmpty)
                }
                if let last = AppState.hevyLastSync {
                    Text("Last sync \(Fmt.mediumDate(last)) · \(model.liftSets.count) sets stored").font(Theme.caption()).foregroundStyle(Theme.tertiary)
                }
                if let hevyStatus { Text(hevyStatus).font(Theme.caption()).foregroundStyle(Theme.secondary) }
            }

            section("Import") {
                Text("Any .xlsx or .csv: a Hevy or Strong export, a MacroFactor or Cronometer export, a coach's template. You map the columns once per source.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PillButton(title: "Import file") { showImporter = true }
                    Button("Blank template") { share { try ExportService.templateFile() } }
                        .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                }
                let mappings = (try? model.context.fetch(FetchDescriptor<ImportMappingRecord>())) ?? []
                if !mappings.isEmpty {
                    Text("Saved mappings: \(mappings.map(\.sourceName).joined(separator: ", "))").font(Theme.caption()).foregroundStyle(Theme.tertiary)
                }
            }

            section("Export") {
                Text("Days, Lifts, Dials, Recommendations and a photo log (dates and stats, no images) as one workbook, or any sheet as CSV.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PillButton(title: "Export .xlsx") { share { try ExportService.xlsxFile(model: model) } }
                    Menu {
                        ForEach(ExportService.workbook(model: model).sheets, id: \.name) { sheet in
                            Button(sheet.name) { share { try ExportService.csvFile(sheet: sheet) } }
                        }
                    } label: {
                        Text("CSV…").font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
            }

            section("Coach") {
                Text("The coach reviews the week every \(Format.weekdayName(model.dials.coachCheckInWeekday, calendar: .current)). Run it now to see what it would say today.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                PillButton(title: "Run check-in now") {
                    model.runCoachNow()
                    model.showToast(model.openRecommendation == nil ? "Nothing to flag this week" : "Check-in ready on Today")
                }
            }

            section("Reset") {
                Button("Delete all data") { confirmWipe = true }.font(Theme.body(.semibold)).foregroundStyle(Theme.behind)
            }

            if let errorText { Text(errorText).font(Theme.caption()).foregroundStyle(Theme.behind).padding(.top, 8) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, UTType(filenameExtension: "xlsx") ?? .data]) { result in
            guard case .success(let url) = result else { return }
            load(url)
        }
        .sheet(item: $candidate) { c in
            ImportMappingView(candidate: c)
        }
        .sheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Delete all data?", isPresented: $confirmWipe) {
            Button("Delete", role: .destructive) { wipe() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every day, set, photo, recommendation, preset and dial change on this phone. Health is untouched.")
        }
    }

    private var healthStatus: String {
        guard HealthSync.isAvailable else { return "Health isn't available on this device." }
        guard AppState.healthAuthorized else { return "Not connected. Tare reads weight, body fat, steps, active energy, food and workouts. It never writes." }
        let last = AppState.healthLastSync.map { "Last sync \(Fmt.mediumDate($0))." } ?? "Not synced yet."
        return "Connected. \(last) \(model.log.count) days stored. Check each app's Health settings to confirm what it shares."
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
            content()
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func syncHevy(full: Bool) async {
        syncingHevy = true
        defer { syncingHevy = false }
        do {
            let o = try await HevyConnector.sync(model: model, fullHistory: full)
            hevyStatus = "Added \(o.setsAdded) sets from \(o.workouts) workouts" + (o.tagged > 0 ? ", tagged \(o.tagged) exercises" : "") + "."
        } catch let e as HevyError {
            hevyStatus = e.localizedDescription
        } catch {
            hevyStatus = error.localizedDescription
        }
    }

    private func share(_ make: () throws -> URL) {
        do { shareURL = try make() } catch { errorText = error.localizedDescription }
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let workbook: Workbook
            if url.pathExtension.lowercased() == "xlsx" {
                workbook = try XLSX.read(data)
            } else {
                let text = String(decoding: data, as: UTF8.self)
                workbook = Workbook(sheets: [Sheet(name: url.deletingPathExtension().lastPathComponent, table: CSV.parse(text))])
            }
            guard workbook.sheets.contains(where: { !$0.table.isEmpty }) else {
                errorText = "That file has no rows."
                return
            }
            candidate = ImportCandidate(fileName: url.deletingPathExtension().lastPathComponent, workbook: workbook)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func wipe() {
        let ctx = model.context
        try? ctx.delete(model: DayRecord.self)
        try? ctx.delete(model: LiftSet.self)
        try? ctx.delete(model: ExerciseMapEntry.self)
        try? ctx.delete(model: ProgressPhoto.self)
        try? ctx.delete(model: Recommendation.self)
        try? ctx.delete(model: ImportMappingRecord.self)
        try? ctx.delete(model: PresetRecord.self)
        try? ctx.delete(model: DialChange.self)
        try? ctx.save()
        AppState.hevyLastSync = nil
        AppState.healthLastSync = nil
        AppState.lastCheckIn = nil
        AppState.rateMisses = 0
        model.reloadAll()
    }
}
