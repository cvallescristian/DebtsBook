
import Foundation
import SwiftData

@Model
class Expense {
    var title: String = ""
    var amount: Decimal = 0
    var isSettled: Bool = false
    var createdAt: Date = Date()
    var date: Date = Date()

    var friend: Friend?
    var paidByMe: Bool = true
    var splitType: SplitType = SplitType.equally
    var comment: String?

    init(title: String, amount: Decimal, friend: Friend? = nil, paidByMe: Bool = true, splitType: SplitType = .equally, date: Date = Date(), comment: String? = nil) {
        self.title = title
        self.amount = amount
        self.friend = friend
        self.paidByMe = paidByMe
        self.splitType = splitType
        self.date = date
        self.comment = comment
        self.createdAt = Date()
    }

    var isPersonal: Bool {
        friend == nil
    }

    var paidByLabel: String {
        guard let friend else { return "You paid" }
        return paidByMe ? "You paid" : "\(friend.name) paid"
    }

    /// The amount that changes hands between you and the friend, after accounting for the split type.
    /// Personal expenses (no friend) aren't a debt, so this is 0.
    var owedAmount: Decimal {
        guard friend != nil else { return 0 }
        return splitType == .equally ? amount / 2 : amount
    }

    var signedAmount: Decimal {
        paidByMe ? owedAmount : -owedAmount
    }

    /// The amount to record in the Activity log: the real amount spent for personal expenses
    /// (which have no debt), or the owed amount for expenses shared with a friend.
    var loggedAmount: Decimal {
        isPersonal ? amount : owedAmount
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
