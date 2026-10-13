import XCTest
@testable import TareEngine

final class DialsTests: XCTestCase {

    func testDefaultsMatchSpecTable() {
        let d = Dials()
        XCTAssertEqual(d.trendAlpha, 0.10)
        XCTAssertEqual(d.outlierThresholdLb, 3)
        XCTAssertEqual(d.dailyLivingPercent, 10)
        XCTAssertEqual(d.stepCostKcalPerStepPerKg, 0.0005)
        XCTAssertEqual(d.met(forLiftStyle: "Heavy"), 3.5)
        XCTAssertEqual(d.met(forLiftStyle: "Hypertrophy"), 5.0)
        XCTAssertEqual(d.met(forLiftStyle: "Supersets"), 6.0)
        XCTAssertEqual(d.met(forCardioType: "Run"), 9.8)
        XCTAssertEqual(d.watchCorrection, 0.85)
        XCTAssertEqual(d.tefProteinPercent, 25)
        XCTAssertEqual(d.tefCarbPercent, 7.5)
        XCTAssertEqual(d.tefFatPercent, 2)
        XCTAssertEqual(d.trustWindowDays, 21)
        XCTAssertEqual(d.minDaysBeforeTrust, 7)
        XCTAssertEqual(d.maxTrustPercent, 90)
        XCTAssertEqual(d.kcalPerLb, 3500)
        XCTAssertEqual(d.ratePercentPerWeek, 0.30)
        XCTAssertTrue(d.cyclingEnabled)
        XCTAssertEqual(d.cyclingShiftPercent, 100)
        XCTAssertEqual(d.proteinGramsPerLb, 1.0)
        XCTAssertEqual(d.fatGramsPerLb, 0.35)
        XCTAssertEqual(d.carbFloorGrams, 50)
        XCTAssertEqual(d.fiberGramsPer1000Kcal, 14)
        XCTAssertEqual(d.roundingKcal, 10)
        XCTAssertEqual(d.waterOzPerLb, 0.5)
        XCTAssertEqual(d.waterOzPerTrainingHour, 12)
        XCTAssertEqual(d.bodyFatCeilingPercent, 18)
        XCTAssertEqual(d.longCutWeeks, 12)
        XCTAssertEqual(d.coachMaxChangeKcal, 250)
    }

    func testJSONRoundTrip() throws {
        var d = Fixture.dials()
        d.trendAlpha = 0.2
        d.liftStyles.append(MetEntry(name: "Circuit", met: 7))
        d.weekdayOffsets[6] = 300
        d.calorieFloor = 2000
        let data = try d.encodedJSON()
        let back = try Dials.decode(json: data)
        XCTAssertEqual(back, d)
    }

    func testOldSaveGetsDefaultsForNewDials() throws {
        let json = #"{"version": 0, "trendAlpha": 0.2, "unknownFutureKey": 42}"#.data(using: .utf8)!
        let d = try Dials.decode(json: json)
        XCTAssertEqual(d.trendAlpha, 0.2)
        XCTAssertEqual(d.trustWindowDays, 21)
        XCTAssertEqual(d.version, Dials.currentVersion)
        XCTAssertEqual(d.liftStyles, Dials.defaultLiftStyles)
    }

    func testMalformedValueFallsBackToDefault() throws {
        let json = #"{"trustWindowDays": "twenty", "outlierThresholdLb": null}"#.data(using: .utf8)!
        let d = try Dials.decode(json: json)
        XCTAssertEqual(d.trustWindowDays, 21)
        XCTAssertNil(d.outlierThresholdLb, "explicit null means the filter is off")
    }

    func testCatalogHas35CoreRows() {
        XCTAssertEqual(DialCatalog.coreRowCount(for: Dials()), 35)
    }

    func testEverySpecRoundTripsThroughGetAndSet() {
        var d = Fixture.dials()
        for spec in DialCatalog.specs(for: d) {
            XCTAssertEqual(d.value(for: spec.key), spec.defaultValue == d.value(for: spec.key) ? spec.defaultValue : d.value(for: spec.key), "\(spec.key)")
            let before = d.value(for: spec.key)
            d.set(before, for: spec.key)
            XCTAssertEqual(d.value(for: spec.key), before, "set should be idempotent for \(spec.key)")
        }
    }

    func testChangedRowsAndReset() {
        var d = Dials()
        XCTAssertEqual(DialCatalog.changedCoreRows(in: d), [])
        d.set(.number(5.5), for: .liftMET("Hypertrophy"))
        d.set(.number(12), for: .dailyLivingPercent)
        d.set(.number(25), for: .tefProteinPercent)
        d.set(.number(7.5), for: .tefCarbPercent)
        XCTAssertEqual(DialCatalog.changedCoreRows(in: d).count, 2)
        XCTAssertFalse(d.isDefault(.dailyLivingPercent))
        d.reset(.dailyLivingPercent)
        XCTAssertTrue(d.isDefault(.dailyLivingPercent))
        d.reset(.liftMET("Hypertrophy"))
        XCTAssertEqual(DialCatalog.changedCoreRows(in: d), [])
    }

    func testWrongShapeValueIsIgnored() {
        var d = Dials()
        d.set(.choice("nope"), for: .trendAlpha)
        XCTAssertEqual(d.trendAlpha, 0.10)
        d.set(.choice("banana"), for: .bmrFormula)
        XCTAssertEqual(d.bmrFormula, .average)
        d.set(.numberList([1, 2]), for: .weekdayOffsets)
        XCTAssertEqual(d.weekdayOffsets.count, 7)
    }

    func testPresetRoundTrip() throws {
        let preset = DialsPreset(name: "Prep, 12 out", created: Date(timeIntervalSince1970: 1_700_000_000), dials: Fixture.dials())
        let data = try Dials.jsonEncoder.encode(preset)
        let back = try Dials.jsonDecoder.decode(DialsPreset.self, from: data)
        XCTAssertEqual(back, preset)
    }
}
