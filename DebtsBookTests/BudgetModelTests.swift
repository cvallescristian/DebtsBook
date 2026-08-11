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
}
