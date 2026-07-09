import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var dateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, end: now)
    }
}

@Model
class Budget {
    var amount: Decimal
    var period: BudgetPeriod = BudgetPeriod.week

    init(amount: Decimal, period: BudgetPeriod) {
        self.amount = amount
        self.period = period
    }
}
