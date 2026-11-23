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

    /// The period `offset` periods away from the one containing `date` (negative = earlier).
    func dateInterval(offset: Int, from date: Date = Date()) -> DateInterval {
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let shifted = Calendar.current.date(byAdding: component, value: offset, to: date) ?? date
        return dateInterval(containing: shifted)
    }

    /// How many periods the period containing `date` is from the one containing `now` (negative = earlier).
    func offset(of date: Date, from now: Date = Date()) -> Int {
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let from = dateInterval(containing: now).start
        let to = dateInterval(containing: date).start
        return Calendar.current.dateComponents([component], from: from, to: to).value(for: component) ?? 0
    }

    /// How many periods the Reports history chart shows.
    var historyLength: Int {
        switch self {
        case .week: return 5
        case .month: return 6
        case .year: return 5
        }
    }

    func label(for interval: DateInterval) -> String {
        switch self {
        case .week:
            let lastDay = interval.end.addingTimeInterval(-1)
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(lastDay.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            return interval.start.formatted(.dateTime.month(.abbreviated).year())
        case .year:
            return interval.start.formatted(.dateTime.year())
        }
    }
}

struct PeriodSpending: Identifiable {
    static let noGroupName = "No Group"

    let offset: Int
    let interval: DateInterval
    let total: Decimal
    /// Spending per group name in this period; expenses without a group fall under `noGroupName`.
    let byGroup: [String: Decimal]
    var id: Int { offset }
}

/// Personal spending totals for the `count` periods ending with the one at `endOffset`, oldest first.
func personalSpendingHistory(
    expenses: [Expense],
    period: BudgetPeriod,
    count: Int,
    endOffset: Int = 0,
    now: Date = Date()
) -> [PeriodSpending] {
    let offsets = (endOffset - count + 1)...endOffset
    return offsets.map { offset in
        let interval = period.dateInterval(offset: offset, from: now)
        let inPeriod = expenses.filter { $0.countsAsSpending && interval.contains($0.date) }
        let total = inPeriod.reduce(Decimal(0)) { $0 + $1.myShare }
        let byGroup = Dictionary(grouping: inPeriod) { $0.group?.name ?? PeriodSpending.noGroupName }
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.myShare } }
        return PeriodSpending(offset: offset, interval: interval, total: total, byGroup: byGroup)
    }
}

@Model
class Budget {
    var amount: Decimal = 0
    var period: BudgetPeriod = BudgetPeriod.week
    var remoteID: UUID?
    /// Changed locally since the last push (set by SyncChangeTracker).
    var isDirty: Bool = false
    @Relationship(deleteRule: .nullify)
    var group: ExpenseGroup?

    init(amount: Decimal, period: BudgetPeriod, group: ExpenseGroup? = nil) {
        self.amount = amount
        self.period = period
        self.group = group
    }
}

/// Warnings for any budget an expense (dated `date`, adding `amount` of your own spending) would push over.
/// Budgets track personal expenses plus your share of grouped shared ones (see `Expense.countsAsSpending`).
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
                .filter { $0.persistentModelID != excludedExpenseID && $0.countsAsSpending && interval.contains($0.date) }
                .reduce(Decimal(0)) { $0 + $1.myShare }
            let newTotal = existingTotal + amount
            guard newTotal > budget.amount else { return nil }
            let over = newTotal - budget.amount
            return "This exceeds your \(budget.period.rawValue.lowercased())ly budget by \(over.formatted(.currency(code: "NZD")))."
        } else if matchesGroup, let budgetGroup = budget.group {
            let interval = budget.period.dateInterval(containing: date)
            let existingTotal = expenses
                .filter { $0.persistentModelID != excludedExpenseID && $0.countsAsSpending && $0.group?.persistentModelID == budgetGroup.persistentModelID && interval.contains($0.date) }
                .reduce(Decimal(0)) { $0 + $1.myShare }
            let newTotal = existingTotal + amount
            guard newTotal > budget.amount else { return nil }
            let over = newTotal - budget.amount
            return "This exceeds your \(budget.period.rawValue.lowercased())ly \(budgetGroup.name) budget by \(over.formatted(.currency(code: "NZD")))."
        }
        return nil
    }
}
