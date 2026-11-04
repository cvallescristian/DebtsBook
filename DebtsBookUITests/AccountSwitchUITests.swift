import XCTest

/// With -accountSwitch, backgrounding and reopening the app opens the "data from another account"
/// sheet over the seeded -uiTesting store (a pending payment, plus friend Sam with a "Dinner"
/// expense), as if a different account had just signed in.
final class AccountSwitchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-requireFaceID", "NO", "-accountSwitch"]
        app.launch()
    }

    private var eraseButton: XCUIElement {
        app.buttons["Erase and Switch"].firstMatch
    }

    private func openAccountSwitchSheet() {
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(eraseButton.waitForExistence(timeout: 15))
    }

    func testSheetOffersBackupEraseAndCancel() {
        openAccountSwitchSheet()
        XCTAssertTrue(app.buttons["Export Backup"].exists)
        XCTAssertTrue(app.buttons["Cancel and Sign Out"].exists)
    }

    func testCancelKeepsLocalData() {
        openAccountSwitchSheet()
        app.buttons["Cancel and Sign Out"].tap()
        XCTAssertTrue(eraseButton.waitForNonExistence(timeout: 15))

        app.tabBars.buttons["Expenses"].tap()
        XCTAssertTrue(app.buttons["pendingExpenseRow"].firstMatch.waitForExistence(timeout: 15))
    }

    func testEraseAndSwitchRemovesLocalData() {
        app.tabBars.buttons["Expenses"].tap()
        XCTAssertTrue(app.staticTexts["Dinner"].waitForExistence(timeout: 15))
        openAccountSwitchSheet()
        eraseButton.tap()
        app.buttons["Erase All Data"].tap()
        XCTAssertTrue(eraseButton.waitForNonExistence(timeout: 15))

        XCTAssertTrue(app.staticTexts["No Expenses"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["pendingExpenseRow"].exists)
    }
}
