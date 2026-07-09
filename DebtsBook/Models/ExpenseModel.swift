
import Foundation
import SwiftData

@Model
class Expense {
    var title: String
    var amount: Decimal
    var isSettled: Bool = false
    var createdAt: Date
    var date: Date

    var friend: Friend?
    var paidByMe: Bool
    var comment: String?

    init(title: String, amount: Decimal, friend: Friend, paidByMe: Bool, date: Date = Date(), comment: String? = nil) {
        self.title = title
        self.amount = amount
        self.friend = friend
        self.paidByMe = paidByMe
        self.date = date
        self.comment = comment
        self.createdAt = Date()
    }

    var paidByLabel: String {
        paidByMe ? "You paid" : "\(friend?.name ?? "Someone") paid"
    }

    var signedAmount: Decimal {
        paidByMe ? amount : -amount
    }
}

extension Array where Element == Expense {
    var netBalance: Decimal {
        reduce(0) { total, expense in
            guard !expense.isSettled else { return total }
            return total + (expense.paidByMe ? expense.amount : -expense.amount)
        }
    }
}
