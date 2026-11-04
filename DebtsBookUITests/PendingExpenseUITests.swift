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
        XCTAssertTrue(pendingRow.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Countdown"].exists)
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Pending · 1")).firstMatch
        XCTAssertTrue(header.exists)
    }

    func testTappingPendingPrefillsNewExpense() {
        openExpenses()
        pendingRow.tap()

        XCTAssertTrue(app.navigationBars["New Expense"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.textFields["Title (e.g. Groceries)"].value as? String, "Countdown")
        let amount = app.textFields["Amount"].value as? String ?? ""
        XCTAssertTrue(amount.contains("42.50"), "Amount was \(amount)")
        XCTAssertTrue(app.buttons["Just Me"].isSelected)
    }

    func testNewExpenseFromExpensesTabStartsAsJustMe() {
        openExpenses()
        app.buttons["Add Expense"].tap()

        XCTAssertTrue(app.navigationBars["New Expense"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Just Me"].isSelected)
    }

    func testLoggingPendingCreatesExpenseAndClearsPending() {
        openExpenses()
        pendingRow.tap()
        XCTAssertTrue(app.navigationBars["New Expense"].waitForExistence(timeout: 15))

        app.buttons["Just Me"].tap()
        app.buttons["Create Expense"].tap()

        XCTAssertTrue(app.navigationBars["Expenses"].waitForExistence(timeout: 15))
        XCTAssertFalse(pendingRow.exists)
        XCTAssertTrue(app.staticTexts["Countdown"].exists)
    }

    func testDismissingPendingRemovesItWithoutAnExpense() {
        openExpenses()
        XCTAssertTrue(pendingRow.waitForExistence(timeout: 15))

        pendingRow.swipeLeft()
        app.buttons["Dismiss"].tap()

        XCTAssertFalse(pendingRow.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Countdown"].exists)
        XCTAssertTrue(app.staticTexts["No Expenses"].exists)
    }

    func testProfileOpensApplePayImportGuide() {
        app.tabBars.buttons["Profile"].tap()
        app.buttons["Apple Pay Import"].tap()

        XCTAssertTrue(app.navigationBars["Apple Pay Import"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Open Shortcuts"].exists)
        XCTAssertTrue(app.buttons["Open Full Guide"].exists)
    }
}
