import XCTest

/// Launches the app with demo data, walks every screen and attaches a screenshot of each.
/// CI exports the attachments and publishes them on the `ci-screenshots` branch.
final class SmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testWalkthrough() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-TareDemoData", "-TareSkipOnboarding"]
        if ProcessInfo.processInfo.environment["TARE_DARK"] == "1" {
            app.launchArguments.append("-TareForceDark")
        }
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "tab bar never appeared")
        pause(1.5)
        shot(app, "01-today")

        let maintenance = app.buttons["number.maintenance"].firstMatch
        if maintenance.waitForExistence(timeout: 5) {
            maintenance.tap()
            pause(2)
            shot(app, "02-detail-maintenance")
            let done = app.buttons["detail.done"].firstMatch
            if done.waitForExistence(timeout: 5) { done.tap() } else { app.swipeDown() }
            pause(1)
        } else {
            XCTFail("Maintenance number not found on Today")
        }

        let coach = app.descendants(matching: .any).matching(identifier: "coachCard").firstMatch
        if coach.waitForExistence(timeout: 3) {
            coach.tap()
            pause(1.5)
            shot(app, "03-coach")
            let back = app.buttons["coach.back"].firstMatch
            if back.waitForExistence(timeout: 5) { back.tap() }
            pause(1)
        } else {
            XCTFail("Coach card not shown with demo data")
        }

        tab(app, "Trend")
        shot(app, "04-trend")

        tab(app, "Progress")
        shot(app, "05-progress-lifts")
        app.swipeUp()
        pause(0.8)
        shot(app, "06-progress-lifts-bottom")
        tapIfPresent(app.buttons["Photos"].firstMatch)
        shot(app, "07-progress-photos")
        tapIfPresent(app.buttons["Body"].firstMatch)
        shot(app, "08-progress-body")

        tab(app, "Plan")
        shot(app, "09-plan")

        tab(app, "Dials")
        shot(app, "10-dials-body")
        tapIfPresent(app.buttons["Activity"].firstMatch)
        shot(app, "11-dials-activity")
        tapIfPresent(app.buttons["Macros"].firstMatch)
        shot(app, "12-dials-macros")
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let button = app.tabBars.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "tab \(name) missing")
        button.tap()
        pause(1.2)
    }

    private func tapIfPresent(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3) {
            element.tap()
            pause(1.2)
        }
    }

    private func pause(_ seconds: Double) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
