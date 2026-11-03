import XCTest

/// Launches the app with -uiTesting: an in-memory store seeded with one pending Apple Pay
/// payment ("Countdown", $42.50, Visa) and no Supabase session.
final class PendingExpenseUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-requireFaceID", "NO"]
        app.launch()
    }

    private func openExpenses() {
        app.tabBars.buttons["Expenses"].tap()
    }

    private var pendingRow: XCUIElement {
        app.buttons["pendingExpenseRow"].firstMatch
    }

    func testExpensesTabShowsPendingPayment() {
        openExpenses()
        XCTAssertTrue(pendingRow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Countdown"].exists)
        let header = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Pending from Apple Pay")).firstMatch
        XCTAssertTrue(header.exists)
    }

    func testTappingPendingPrefillsNewExpense() {
        openExpenses()
        pendingRow.tap()

        XCTAssertTrue(app.navigationBars["New Expense"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Title (e.g. Groceries)"].value as? String, "Countdown")
        let amount = app.textFields["Amount"].value as? String ?? ""
        XCTAssertTrue(amount.contains("42.50"), "Amount was \(amount)")
    }

    func testLoggingPendingCreatesExpenseAndClearsPending() {
        openExpenses()
        pendingRow.tap()
        XCTAssertTrue(app.navigationBars["New Expense"].waitForExistence(timeout: 5))

        app.buttons["Just Me"].tap()
        app.buttons["Create Expense"].tap()

        XCTAssertTrue(app.navigationBars["Expenses"].waitForExistence(timeout: 5))
        XCTAssertFalse(pendingRow.exists)
        XCTAssertTrue(app.staticTexts["Countdown"].exists)
    }

    func testDismissingPendingRemovesItWithoutAnExpense() {
        openExpenses()
        XCTAssertTrue(pendingRow.waitForExistence(timeout: 5))

        pendingRow.swipeLeft()
        app.buttons["Dismiss"].tap()

        XCTAssertFalse(pendingRow.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Countdown"].exists)
        XCTAssertTrue(app.staticTexts["No Expenses"].exists)
    }

    func testProfileOpensApplePayImportGuide() {
        app.tabBars.buttons["Profile"].tap()
        app.buttons["Apple Pay Import"].tap()

        XCTAssertTrue(app.navigationBars["Apple Pay Import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Shortcuts"].exists)
    }
}
