import XCTest
@testable import TareEngine

final class TrendAndRegressionTests: XCTestCase {

    func testLinearFitRecoversLine() {
        let pts = (0..<10).map { (x: Double($0), y: 3 + 0.5 * Double($0)) }
        let fit = LinearFit.fit(pts)!
        XCTAssertEqual(fit.slope, 0.5, accuracy: 1e-9)
        XCTAssertEqual(fit.intercept, 3, accuracy: 1e-9)
        XCTAssertNil(LinearFit.fit([(x: 1, y: 2)]))
        XCTAssertNil(LinearFit.fit([(x: 1, y: 2), (x: 1, y: 3)]))
    }

    func testEMA() {
        let pts = TrendWeight.series(weighIns: [(Fixture.day(2), 180), (Fixture.day(1), 182), (Fixture.day(0), 181)], alpha: 0.1, outlierThresholdLb: nil)
        XCTAssertEqual(pts.map(\.trendLb), [180, 180.2, 180.28], accuracy: 1e-9)
    }

    func testOutlierSkippedThenAcceptedAfterThree() {
        var weighIns: [(date: Date, weightLb: Double)] = [(Fixture.day(10), 180)]
        weighIns.append((Fixture.day(9), 185))   // outlier 1: skipped
        weighIns.append((Fixture.day(8), 180.5)) // normal
        weighIns.append((Fixture.day(7), 186))   // outlier 1
        weighIns.append((Fixture.day(6), 186))   // outlier 2
        weighIns.append((Fixture.day(5), 186))   // third in a row: accepted
        let pts = TrendWeight.series(weighIns: weighIns, alpha: 0.1, outlierThresholdLb: 3)
        XCTAssertEqual(pts.map(\.isOutlier), [false, true, false, true, true, false])
        XCTAssertEqual(pts[1].trendLb, 180, "an outlier leaves the trend alone")
        XCTAssertEqual(pts[2].trendLb, 180.05, accuracy: 1e-9)
        XCTAssertGreaterThan(pts[5].trendLb, pts[4].trendLb)
    }

    func testOutlierFilterOff() {
        let pts = TrendWeight.series(weighIns: [(Fixture.day(1), 180), (Fixture.day(0), 190)], alpha: 0.1, outlierThresholdLb: nil)
        XCTAssertEqual(pts[1].trendLb, 181, accuracy: 1e-9)
        XCTAssertFalse(pts[1].isOutlier)
    }

    func testUnsortedInputIsSorted() {
        let pts = TrendWeight.series(weighIns: [(Fixture.day(0), 181), (Fixture.day(2), 180), (Fixture.day(1), 182)], alpha: 0.1, outlierThresholdLb: nil)
        XCTAssertEqual(pts.map(\.weightLb), [180, 182, 181])
    }
}

func XCTAssertEqual(_ a: [Double], _ b: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.count, b.count, file: file, line: line)
    for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: accuracy, file: file, line: line) }
}
