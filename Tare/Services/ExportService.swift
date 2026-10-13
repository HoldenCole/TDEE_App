import Foundation
import SwiftData
import TareEngine
import TareFiles

/// Builds the export workbook and CSVs from the store.
@MainActor
enum ExportService {
    static func workbook(model: AppModel, includePhotoLog: Bool = true) -> Workbook {
        let recs = model.allRecommendations().map { r in
            RecommendationRow(date: r.date, rule: r.rule.title, headline: r.headline, status: r.status.rawValue, kcalChange: r.appliedKcalChange ?? r.decoded?.kcalChange, detail: r.decoded?.reason ?? "")
        }
        var photos: [PhotoLogRow] = []
        if includePhotoLog {
            let all = (try? model.context.fetch(FetchDescriptor<ProgressPhoto>(sortBy: [SortDescriptor(\.date)]))) ?? []
            photos = all.map { PhotoLogRow(date: $0.date, pose: $0.poseTitle, trendWeightLb: $0.trendWeightLb, bodyFatPercent: $0.bodyFatPercent, phase: $0.phase?.title ?? "") }
        }
        return ExportBuilder.workbook(days: model.log, lifts: model.liftSets, dials: model.dials, recommendations: recs, photos: photos)
    }

    static func xlsxFile(model: AppModel) throws -> URL {
        let data = try XLSX.write(workbook(model: model))
        return try write(data, name: "Tare export \(stamp()).xlsx")
    }

    static func csvFile(sheet: Sheet) throws -> URL {
        let text = CSV.write(sheet.table)
        return try write(Data(text.utf8), name: "Tare \(sheet.name) \(stamp()).csv")
    }

    static func templateFile() throws -> URL {
        let data = try XLSX.write(ExportBuilder.template())
        return try write(data, name: "Tare template.xlsx")
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func write(_ data: Data, name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
