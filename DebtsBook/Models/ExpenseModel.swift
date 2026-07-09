
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
    var splitType: SplitType
    var comment: String?

    init(title: String, amount: Decimal, friend: Friend, paidByMe: Bool, splitType: SplitType = .equally, date: Date = Date(), comment: String? = nil) {
        self.title = title
        self.amount = amount
        self.friend = friend
        self.paidByMe = paidByMe
        self.splitType = splitType
        self.date = date
        self.comment = comment
        self.createdAt = Date()
    }

    var paidByLabel: String {
        paidByMe ? "You paid" : "\(friend?.name ?? "Someone") paid"
    }

    /// The amount that changes hands between you and the friend, after accounting for the split type.
    var owedAmount: Decimal {
        splitType == .equally ? amount / 2 : amount
    }

    var signedAmount: Decimal {
        paidByMe ? owedAmount : -owedAmount
    }
}

enum SplitType: String, Codable {
    case equally
    case fullAmount
}

extension Array where Element == Expense {
    var netBalance: Decimal {
        reduce(0) { total, expense in
            guard !expense.isSettled else { return total }
            return total + expense.signedAmount
        }
    }
}
