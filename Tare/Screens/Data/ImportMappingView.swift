import SwiftUI
import SwiftData
import TareEngine
import TareFiles

/// What a picked file parsed into, before mapping.
struct ImportCandidate: Identifiable {
    let id = UUID()
    let fileName: String
    let workbook: Workbook
}

/// The mapping screen: guesses each column, lets the user fix it, remembers the mapping per source.
struct ImportMappingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let candidate: ImportCandidate

    @State private var sheetIndex = 0
    @State private var mapping = ColumnMapping()
    @State private var sourceName = ""
    @State private var weightUnit: WeightUnit = .lb
    @State private var result: String?
    @State private var importing = false

    private var sheet: Sheet { candidate.workbook.sheets[min(sheetIndex, candidate.workbook.sheets.count - 1)] }
    private var table: Table { sheet.table }

    var body: some View {
        NavigationStack {
            Form {
                if candidate.workbook.sheets.count > 1 {
                    Picker("Sheet", selection: $sheetIndex) {
                        ForEach(Array(candidate.workbook.sheets.enumerated()), id: \.offset) { i, s in
                            Text("\(s.name) (\(s.table.rows.count) rows)").tag(i)
                        }
                    }
                    .onChange(of: sheetIndex) { _, _ in guessMapping() }
                }
                Section {
                    TextField("Source name", text: $sourceName)
                    Picker("Weight unit", selection: $weightUnit) {
                        Text("lb").tag(WeightUnit.lb)
                        Text("kg").tag(WeightUnit.kg)
                    }
                } header: {
                    Text("Source")
                } footer: {
                    Text("The mapping is saved under this name, so the next \(sourceName.isEmpty ? "export from the same app" : "\(sourceName) export") imports without this step. \(table.rows.count) rows, \(table.columns.count) columns.")
                }
                Section("Columns") {
                    ForEach(table.columns, id: \.self) { column in
                        Picker(selection: Binding(get: { mapping[column] ?? .ignore }, set: { mapping[column] = $0 })) {
                            ForEach(ImportField.allCases, id: \.self) { f in Text(f.title).tag(f) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(column).font(Theme.body(.semibold))
                                if let sample = table.rows.first?[safe: table.columnIndex(column) ?? -1], !sample.isEmpty {
                                    Text("e.g. \(sample)").font(Theme.captionSmall()).foregroundStyle(Theme.tertiary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text(mapping.describesLifts ? "This looks like set-level lifting data. It will fill Lifts." : "This looks like daily data. It will merge into your Days, overriding fields the file provides.")
                        .font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
                if let result {
                    Section { Text(result).font(Theme.body()).foregroundStyle(Theme.ink) }
                }
            }
            .navigationTitle("Map columns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(importing ? "Importing…" : "Import") { runImport() }.disabled(importing || !mapping.contains(.date))
                }
            }
            .onAppear { guessMapping() }
        }
    }

    private func guessMapping() {
        let detected = MappingGuesser.detectSource(columns: table.columns)
        sourceName = detected ?? candidate.fileName
        if let saved = savedMapping(for: sourceName) {
            mapping = saved.0
            weightUnit = saved.1
        } else {
            mapping = MappingGuesser.guess(columns: table.columns)
            if table.columns.contains(where: { $0.lowercased().contains("kg") }) { weightUnit = .kg }
        }
    }

    private func savedMapping(for name: String) -> (ColumnMapping, WeightUnit)? {
        var d = FetchDescriptor<ImportMappingRecord>(predicate: #Predicate { $0.sourceName == name })
        d.fetchLimit = 1
        guard let record = try? model.context.fetch(d).first, let m = try? JSONDecoder().decode(ColumnMapping.self, from: record.mappingJSON) else { return nil }
        // Only reuse when the saved columns still exist in this file.
        guard Set(m.fields.keys).isSubset(of: Set(table.columns)) else { return nil }
        return (m, WeightUnit(rawValue: record.weightUnit) ?? .lb)
    }

    private func runImport() {
        importing = true
        let options = ImportOptions(weightUnit: weightUnit)
        let name = sourceName.trimmingCharacters(in: .whitespaces)
        if mapping.describesLifts {
            let r = ImportParser.liftSets(from: table, mapping: mapping, options: options, source: name.isEmpty ? nil : name)
            let added = model.addLiftSets(r.items, batchID: candidate.fileName)
            result = "Imported \(added) new sets (\(r.items.count) in file, \(r.skippedRows) rows skipped)." + (r.problems.isEmpty ? "" : " " + r.problems.prefix(3).joined(separator: " "))
        } else {
            let r = ImportParser.days(from: table, mapping: mapping, options: options)
            model.upsertDays(r.items, synced: false)
            result = "Imported \(r.items.count) days (\(r.skippedRows) rows skipped)." + (r.problems.isEmpty ? "" : " " + r.problems.prefix(3).joined(separator: " "))
        }
        saveMapping(name: name)
        importing = false
        model.showToast(result ?? "Imported")
        dismiss()
    }

    private func saveMapping(name: String) {
        guard !name.isEmpty, let data = try? JSONEncoder().encode(mapping) else { return }
        var d = FetchDescriptor<ImportMappingRecord>(predicate: #Predicate { $0.sourceName == name })
        d.fetchLimit = 1
        if let existing = try? model.context.fetch(d).first {
            existing.mappingJSON = data
            existing.weightUnit = weightUnit.rawValue
            existing.lastUsed = Date()
        } else {
            model.context.insert(ImportMappingRecord(sourceName: name, mappingJSON: data, weightUnit: weightUnit.rawValue))
        }
        try? model.context.save()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
