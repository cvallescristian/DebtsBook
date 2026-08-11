import Testing
import Foundation
@testable import DebtsBook

struct ExpenseModelTests {

    @Test func personalExpenseHasNoDebt() {
        let expense = Expense(title: "Coffee", amount: 5)
        #expect(expense.isPersonal)
        #expect(expense.owedAmount == 0)
        #expect(expense.signedAmount == 0)
        #expect(expense.paidByLabel == "You paid")
        #expect(expense.loggedAmount == 5)
    }

    @Test func splitEquallyOwesHalf() {
        let friend = Friend(name: "Ana")
        let expense = Expense(title: "Dinner", amount: 30, friend: friend, paidByMe: true, splitType: .equally)
        #expect(expense.owedAmount == 15)
        #expect(expense.signedAmount == 15)
        #expect(expense.loggedAmount == 15)
        #expect(expense.paidByLabel == "You paid")
    }

    @Test func splitFullAmountOwesEverything() {
        let friend = Friend(name: "Ana")
        let expense = Expense(title: "Gift", amount: 40, friend: friend, paidByMe: false, splitType: .fullAmount)
        #expect(expense.owedAmount == 40)
        #expect(expense.signedAmount == -40)
        #expect(expense.paidByLabel == "Ana paid")
    }

    @Test func friendPaidFlipsSignedAmountNegative() {
        let friend = Friend(name: "Ana")
        let expense = Expense(title: "Taxi", amount: 20, friend: friend, paidByMe: false)
        #expect(expense.signedAmount == -10)
    }

    @Test func netBalanceExcludesSettledExpenses() {
        let friend = Friend(name: "Ana")
        let unsettled = Expense(title: "Lunch", amount: 20, friend: friend, paidByMe: true)
        let settled = Expense(title: "Old debt", amount: 100, friend: friend, paidByMe: true)
        settled.isSettled = true
        let expenses = [unsettled, settled]
        #expect(expenses.netBalance == 10)
    }

    @Test func netBalanceIgnoresPersonalExpenses() {
        let personal = Expense(title: "Coffee", amount: 50)
        let friend = Friend(name: "Ana")
        let shared = Expense(title: "Lunch", amount: 20, friend: friend, paidByMe: true)
        #expect([personal, shared].netBalance == 10)
    }
}
