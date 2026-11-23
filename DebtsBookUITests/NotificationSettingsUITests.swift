import XCTest

final class NotificationSettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-requireFaceID", "NO", "-notifyFriendChanges", "NO"]
        app.launch()
    }

    func testProfileOpensNotificationSettings() {
        app.tabBars.buttons["Profile"].tap()
        let link = app.buttons["notificationSettingsLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()

        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.switches["Allow Notifications"].exists)
        let expenseChanges = app.switches["Adds, Edits, or Deletes an Expense"]
        XCTAssertTrue(expenseChanges.exists)
        XCTAssertFalse(expenseChanges.isEnabled, "Per-type switches should be disabled while notifications are off")
    }
}
