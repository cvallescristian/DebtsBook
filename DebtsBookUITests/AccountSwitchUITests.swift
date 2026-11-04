import XCTest

/// -accountSwitch opens the "data from another account" sheet over the seeded -uiTesting store
/// (one pending Apple Pay payment), as if a different account had just signed in.
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

    func testSheetOffersBackupEraseAndCancel() {
        XCTAssertTrue(eraseButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export Backup"].exists)
        XCTAssertTrue(app.buttons["Cancel and Sign Out"].exists)
    }

    func testCancelKeepsLocalData() {
        XCTAssertTrue(eraseButton.waitForExistence(timeout: 5))
        app.buttons["Cancel and Sign Out"].tap()
        XCTAssertTrue(eraseButton.waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Expenses"].tap()
        XCTAssertTrue(app.buttons["pendingExpenseRow"].firstMatch.waitForExistence(timeout: 5))
    }

    func testEraseAndSwitchRemovesLocalData() {
        app.tabBars.buttons["Expenses"].tap()
        XCTAssertTrue(app.staticTexts["Dinner"].waitForExistence(timeout: 5))
        XCTAssertTrue(eraseButton.waitForExistence(timeout: 5))
        eraseButton.tap()
        app.buttons["Erase All Data"].tap()
        XCTAssertTrue(eraseButton.waitForNonExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["No Expenses"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pendingExpenseRow"].exists)
    }
}
