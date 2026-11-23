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

    @Test func myShareFollowsTheSplit() {
        let friend = Friend(name: "Ana")
        let group = ExpenseGroup(name: "Eating out")
        #expect(Expense(title: "Coffee", amount: 5).myShare == 5)
        #expect(Expense(title: "Dinner", amount: 80, friend: friend, group: group, paidByMe: true, splitType: .equally).myShare == 40)
        #expect(Expense(title: "Dinner", amount: 80, friend: friend, group: group, paidByMe: false, splitType: .equally).myShare == 40)
        #expect(Expense(title: "Gift", amount: 80, friend: friend, group: group, paidByMe: true, splitType: .fullAmount).myShare == 0)
        #expect(Expense(title: "Loan", amount: 80, friend: friend, group: group, paidByMe: false, splitType: .fullAmount).myShare == 80)
    }

    @Test func sharedExpenseCountsAsSpendingOnlyWithAGroup() {
        let friend = Friend(name: "Ana")
        let group = ExpenseGroup(name: "Eating out")
        #expect(Expense(title: "Coffee", amount: 5).countsAsSpending)
        #expect(!Expense(title: "Dinner", amount: 80, friend: friend).countsAsSpending)
        #expect(Expense(title: "Dinner", amount: 80, friend: friend, group: group).countsAsSpending)
        #expect(!Expense(title: "Gift", amount: 80, friend: friend, group: group, paidByMe: true, splitType: .fullAmount).countsAsSpending)
    }

    @Test func settlingUpDoesNotChangeMyShare() {
        let friend = Friend(name: "Ana")
        let expense = Expense(title: "Dinner", amount: 80, friend: friend, group: ExpenseGroup(name: "Eating out"), paidByMe: false)
        expense.isSettled = true
        #expect(expense.myShare == 40)
        #expect(expense.countsAsSpending)
    }

    @Test func onlyUndecidedLinkedExpensesWithAShareNeedCategorizing() {
        let sam = Friend(name: "Sam")
        sam.linkedUserID = UUID()
        let date = Expense.categorizeCutoff.addingTimeInterval(3600)
        let dinner = Expense(title: "Dinner", amount: 80, friend: sam, paidByMe: false, date: date)
        #expect(dinner.needsCategorizing)

        dinner.groupDecided = true
        #expect(!dinner.needsCategorizing)

        let gift = Expense(title: "Gift", amount: 80, friend: sam, paidByMe: true, splitType: .fullAmount, date: date)
        #expect(!gift.needsCategorizing)

        let old = Expense(title: "Old", amount: 80, friend: sam, date: Expense.categorizeCutoff.addingTimeInterval(-3600))
        #expect(!old.needsCategorizing)

        let unlinked = Expense(title: "Taxi", amount: 20, friend: Friend(name: "Ana"), date: date)
        #expect(!unlinked.needsCategorizing)
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

    @Test func periodTotalsOnlyCountExpensesInTheInterval() {
        let friend = Friend(name: "Ana")
        let now = Date()
        let week = BudgetPeriod.week.dateInterval(containing: now)
        let lastWeek = BudgetPeriod.week.dateInterval(offset: -1, from: now).start.addingTimeInterval(3600)
        let dinner = Expense(title: "Dinner", amount: 100, friend: friend, paidByMe: true, splitType: .equally, date: now)
        let taxi = Expense(title: "Taxi", amount: 30, friend: friend, paidByMe: false, splitType: .fullAmount, date: now)
        let old = Expense(title: "Old", amount: 500, friend: friend, date: lastWeek)

        let inWeek = [dinner, taxi, old].dated(in: week)

        #expect(inWeek.count == 2)
        #expect(inWeek.totalAmount == 130)
        #expect(inWeek.totalMyShare == 80)
    }

    @Test func expenseOnAPeriodBoundaryBelongsToTheNextPeriod() {
        let week = BudgetPeriod.week.dateInterval(containing: Date())
        let onBoundary = Expense(title: "Midnight", amount: 10, date: week.end)
        #expect([onBoundary].dated(in: week).isEmpty)
    }
}
