import Testing
import Foundation
import SwiftData
@testable import DebtsBook

@MainActor
struct PendingExpenseTests {

    private func makeContext() throws -> ModelContext {
        let context = TestModelContainer.shared.mainContext
        for pending in try context.fetch(FetchDescriptor<PendingExpense>()) {
            context.delete(pending)
        }
        return context
    }

    @Test(arguments: [
        ("$12.50", Decimal(string: "12.50")),
        ("NZ$1,234.50", Decimal(string: "1234.50")),
        ("12,50 €", Decimal(string: "12.50")),
        ("1.234,5", Decimal(string: "1234.5")),
        ("$1,234", Decimal(string: "1234")),
        ("$5", Decimal(string: "5")),
        ("$.99", Decimal(string: "0.99")),
    ])
    func parsesFormattedAmounts(text: String, expected: Decimal?) {
        #expect(PendingExpense.parseAmount(text) == expected)
    }

    @Test func rejectsTextWithoutDigits() {
        #expect(PendingExpense.parseAmount("") == nil)
        #expect(PendingExpense.parseAmount("free") == nil)
    }

    @Test func addsNewPayment() throws {
        let context = try makeContext()
        let added = PendingExpense.add(merchant: "Countdown", amount: 42, cardName: "Visa", to: context)
        #expect(added)
        #expect(try context.fetchCount(FetchDescriptor<PendingExpense>()) == 1)
    }

    @Test func skipsSamePaymentWithinAMinute() throws {
        let context = try makeContext()
        let date = Date()
        PendingExpense.add(merchant: "Countdown", amount: 42, cardName: "Visa", date: date, to: context)
        let added = PendingExpense.add(merchant: "Countdown", amount: 42, cardName: "Watch", date: date.addingTimeInterval(30), to: context)
        #expect(!added)
        #expect(try context.fetchCount(FetchDescriptor<PendingExpense>()) == 1)
    }

    @Test func keepsRepeatPurchaseLaterOn() throws {
        let context = try makeContext()
        let date = Date()
        PendingExpense.add(merchant: "Coffee", amount: 5, cardName: nil, date: date, to: context)
        let added = PendingExpense.add(merchant: "Coffee", amount: 5, cardName: nil, date: date.addingTimeInterval(600), to: context)
        #expect(added)
        #expect(try context.fetchCount(FetchDescriptor<PendingExpense>()) == 2)
    }
}
