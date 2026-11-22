import Testing
import Foundation
@testable import DebtsBook

struct BudgetModelTests {

    @Test func personalExpenseUnderBudgetHasNoWarning() {
        let budget = Budget(amount: 100, period: .week)
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [], amount: 50, date: Date())
        #expect(warnings.isEmpty)
    }

    @Test func personalExpenseOverGlobalBudgetWarns() {
        let budget = Budget(amount: 100, period: .week)
        let existing = Expense(title: "Groceries", amount: 80, date: Date())
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [existing], amount: 30, date: Date())
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("exceeds your weekly budget") == true)
    }

    @Test func exactlyAtBudgetDoesNotWarn() {
        let budget = Budget(amount: 100, period: .week)
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [], amount: 100, date: Date())
        #expect(warnings.isEmpty)
    }

    @Test func sharedExpensesDoNotCountTowardPersonalBudget() {
        let budget = Budget(amount: 50, period: .week)
        let friend = Friend(name: "Ana")
        let shared = Expense(title: "Dinner", amount: 200, friend: friend, paidByMe: true, date: Date())
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [shared], amount: 10, date: Date())
        #expect(warnings.isEmpty)
    }

    @Test func editingAnExpenseExcludesItFromItsOwnTotal() {
        let budget = Budget(amount: 100, period: .week)
        let existing = Expense(title: "Groceries", amount: 90, date: Date())
        let warnings = exceededBudgetWarnings(
            budgets: [budget],
            expenses: [existing],
            amount: 90,
            date: Date(),
            excluding: existing.persistentModelID
        )
        #expect(warnings.isEmpty)
    }

    @Test func groupBudgetOnlyCountsMatchingGroup() {
        let food = ExpenseGroup(name: "Food")
        let transport = ExpenseGroup(name: "Transport")
        let budget = Budget(amount: 50, period: .week, group: food)
        let transportExpense = Expense(title: "Bus", amount: 200, group: transport, date: Date())
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [transportExpense], amount: 10, date: Date(), groupID: food.persistentModelID)
        #expect(warnings.isEmpty)
    }

    @Test func groupBudgetWarnsWhenItsOwnGroupIsOver() {
        let food = ExpenseGroup(name: "Food")
        let budget = Budget(amount: 50, period: .week, group: food)
        let existing = Expense(title: "Groceries", amount: 40, group: food, date: Date())
        let warnings = exceededBudgetWarnings(budgets: [budget], expenses: [existing], amount: 20, date: Date(), groupID: food.persistentModelID)
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("Food budget") == true)
    }

    @Test func previousPeriodIntervalIsImmediatelyBeforeCurrent() {
        let current = BudgetPeriod.month.dateInterval()
        let previous = BudgetPeriod.month.dateInterval(offset: -1)
        #expect(previous.end == current.start)
    }

    @Test func spendingHistoryTotalsEachPeriodOldestFirst() {
        let now = Date()
        let lastWeek = BudgetPeriod.week.dateInterval(offset: -1, from: now).start.addingTimeInterval(3600)
        let thisWeek = Expense(title: "Coffee", amount: 5, date: now)
        let earlier = Expense(title: "Books", amount: 40, date: lastWeek)
        let shared = Expense(title: "Dinner", amount: 100, friend: Friend(name: "Ana"), paidByMe: true, date: now)

        let history = personalSpendingHistory(expenses: [thisWeek, earlier, shared], period: .week, count: 3, now: now)

        #expect(history.map(\.offset) == [-2, -1, 0])
        #expect(history.map(\.total) == [0, 40, 5])
    }

    @Test func spendingHistoryCanEndAtAnEarlierPeriod() {
        let history = personalSpendingHistory(expenses: [], period: .month, count: 6, endOffset: -10)
        #expect(history.first?.offset == -15)
        #expect(history.last?.offset == -10)
    }

    @Test func spendingHistorySplitsTotalsByGroup() {
        let now = Date()
        let food = ExpenseGroup(name: "Food")
        let lunch = Expense(title: "Lunch", amount: 20, group: food, date: now)
        let snack = Expense(title: "Snack", amount: 5, group: food, date: now)
        let misc = Expense(title: "Misc", amount: 10, date: now)

        let history = personalSpendingHistory(expenses: [lunch, snack, misc], period: .week, count: 1, now: now)

        #expect(history.first?.byGroup == ["Food": 25, PeriodSpending.noGroupName: 10])
        #expect(history.first?.total == 35)
    }
}
