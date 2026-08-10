import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    func dateInterval(containing date: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, end: date)
    }
}

@Model
class Budget {
    var amount: Decimal = 0
    var period: BudgetPeriod = BudgetPeriod.week
    @Relationship(deleteRule: .nullify)
    var group: ExpenseGroup?

    init(amount: Decimal, period: BudgetPeriod, group: ExpenseGroup? = nil) {
        self.amount = amount
        self.period = period
        self.group = group
    }
}

/// Warnings for any budget a personal expense (dated `date`, costing `amount`) would push over.
/// Budgets only track personal spending, not expenses shared with friends.
/// Pass `excluding` when editing an existing expense so it isn't double-counted against itself.
func exceededBudgetWarnings(
    budgets: [Budget],
    expenses: [Expense],
    amount: Decimal,
    date: Date,
    groupID: PersistentIdentifier? = nil,
    excluding excludedExpenseID: PersistentIdentifier? = nil
) -> [String] {
    budgets.compactMap { budget in
        let isGlobalBudget = budget.group == nil
        let matchesGroup = budget.group?.persistentModelID == groupID

        if isGlobalBudget {
            let interval = budget.period.dateInterval(containing: date)
            let existingTotal = expenses
                .filter { $0.persistentModelID != excludedExpenseID && $0.isPersonal && interval.contains($0.date) }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let newTotal = existingTotal + amount
            guard newTotal > budget.amount else { return nil }
            let over = newTotal - budget.amount
            return "This exceeds your \(budget.period.rawValue.lowercased())ly budget by \(over.formatted(.currency(code: "NZD")))."
        } else if matchesGroup, let budgetGroup = budget.group {
            let interval = budget.period.dateInterval(containing: date)
            let existingTotal = expenses
                .filter { $0.persistentModelID != excludedExpenseID && $0.group?.persistentModelID == budgetGroup.persistentModelID && interval.contains($0.date) }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let newTotal = existingTotal + amount
            guard newTotal > budget.amount else { return nil }
            let over = newTotal - budget.amount
            return "This exceeds your \(budget.period.rawValue.lowercased())ly \(budgetGroup.name) budget by \(over.formatted(.currency(code: "NZD")))."
        }
        return nil
    }
}
