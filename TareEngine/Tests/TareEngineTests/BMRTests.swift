import XCTest
@testable import TareEngine

final class BMRTests: XCTestCase {
    let inputs = BMRInputs(weightKg: 84, heightCm: 180, ageYears: 30, sex: .male, leanMassKg: 70)

    func testFormulas() {
        XCTAssertEqual(BMRCalculator.mifflin(weightKg: 84, heightCm: 180, age: 30, sex: .male), 1820, accuracy: 0.01)
        XCTAssertEqual(BMRCalculator.mifflin(weightKg: 60, heightCm: 165, age: 28, sex: .female), 600 + 1031.25 - 140 - 161, accuracy: 0.01)
        XCTAssertEqual(BMRCalculator.katchMcArdle(leanMassKg: 70), 1882, accuracy: 0.01)
        XCTAssertEqual(BMRCalculator.cunningham(leanMassKg: 70), 2040, accuracy: 0.01)
        XCTAssertEqual(BMRCalculator.harrisBenedict(weightKg: 84, heightCm: 180, age: 30, sex: .male), 88.4 + 1125.6 + 864 - 171, accuracy: 0.01)
        XCTAssertEqual(BMRCalculator.harrisBenedict(weightKg: 60, heightCm: 165, age: 28, sex: .female), 447.6 + 552 + 511.5 - 120.4, accuracy: 0.01)
    }

    func testAverageOfAvailable() {
        let r = BMRCalculator.compute(inputs, dials: Dials())
        let expected = (1820 + 1882 + 2040 + 1907) / 4.0
        XCTAssertEqual(r.value, expected, accuracy: 0.01)
        XCTAssertEqual(r.used.count, 4)
        XCTAssertFalse(r.isFallback)
    }

    func testAverageSkipsFormulasWithoutInputs() {
        let noLBM = BMRInputs(weightKg: 84, heightCm: 180, ageYears: 30, sex: .male, leanMassKg: nil)
        let r = BMRCalculator.compute(noLBM, dials: Dials())
        XCTAssertEqual(r.value, (1820 + 1907) / 2.0, accuracy: 0.01)
        XCTAssertEqual(Set(r.used), [.mifflin, .harrisBenedict])
    }

    func testSpecificFormulaAndFallbackWhenUnavailable() {
        var d = Dials()
        d.bmrFormula = .katchMcArdle
        XCTAssertEqual(BMRCalculator.compute(inputs, dials: d).value, 1882, accuracy: 0.01)
        let noLBM = BMRInputs(weightKg: 84, heightCm: 180, ageYears: 30, sex: .male, leanMassKg: nil)
        XCTAssertEqual(BMRCalculator.compute(noLBM, dials: d).value, (1820 + 1907) / 2.0, accuracy: 0.01, "falls back to the average when Katch can't run")
    }

    func testWeightedBlend() {
        var d = Dials()
        d.bmrFormula = .weighted
        d.bmrWeights = BMRWeights(mifflin: 3, katchMcArdle: 1, cunningham: 0, harrisBenedict: 0)
        XCTAssertEqual(BMRCalculator.compute(inputs, dials: d).value, (3 * 1820 + 1882) / 4.0, accuracy: 0.01)
    }

    func testMeasuredOverrideAndAdjustment() {
        var d = Dials()
        d.measuredRMR = 1750
        d.bmrAdjustmentPercent = 10
        let r = BMRCalculator.compute(inputs, dials: d)
        XCTAssertEqual(r.value, 1750, "measured RMR ignores the adjustment")
        XCTAssertTrue(r.isMeasured)
        d.measuredRMR = nil
        d.bmrFormula = .mifflin
        XCTAssertEqual(BMRCalculator.compute(inputs, dials: d).value, 1820 * 1.1, accuracy: 0.01)
    }

    func testFallbackWhenNothingComputable() {
        let bare = BMRInputs(weightKg: 84, heightCm: nil, ageYears: nil, sex: .male, leanMassKg: nil)
        let r = BMRCalculator.compute(bare, dials: Dials())
        XCTAssertTrue(r.isFallback)
        XCTAssertEqual(r.value, 84 * 22, accuracy: 0.01)
    }
}
