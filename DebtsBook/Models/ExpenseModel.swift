
import Foundation
import SwiftData

@Model
class Expense {
    var title: String = ""
    var amount: Decimal = 0
    var isSettled: Bool = false
    var createdAt: Date = Date()
    var date: Date = Date()
    var remoteID: UUID?
    /// Changed locally since the last push (set by SyncChangeTracker).
    var isDirty: Bool = false
    /// A shared expense's group changed and isn't uploaded yet. Shared rows never stay
    /// `isDirty` (their service pushes them right away), but your group for one goes to the
    /// owner-only shared_expense_groups table with the owner sync.
    var groupNeedsSync: Bool = false
    /// You picked a group for this shared expense, or skipped it, so it's out of "To categorize".
    /// Synced as the existence of your shared_expense_groups row (a null group means skipped).
    var groupDecided: Bool = false

    @Relationship(deleteRule: .nullify)
    var friend: Friend?
    @Relationship(deleteRule: .nullify)
    var group: ExpenseGroup?
    var paidByMe: Bool = true
    var splitType: SplitType = SplitType.equally
    var comment: String?

    init(title: String, amount: Decimal, friend: Friend? = nil, group: ExpenseGroup? = nil, paidByMe: Bool = true, splitType: SplitType = .equally, date: Date = Date(), comment: String? = nil) {
        self.title = title
        self.amount = amount
        self.friend = friend
        self.group = group
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

    /// What you yourself spent, for Reports and budgets: the full amount for personal expenses,
    /// your part of the split for shared ones. Settling up doesn't change it, since paying a
    /// friend back is moving money, not new spending.
    var myShare: Decimal {
        guard friend != nil else { return amount }
        return Expense.myShare(of: amount, splitType: splitType, paidByMe: paidByMe)
    }

    /// Personal expenses always count as spending; shared ones only once you give them a group.
    var countsAsSpending: Bool {
        if isPersonal {
            return true
        }
        return group != nil && myShare > 0
    }

    /// Shared expenses dated from here on wait in "To categorize"; older history would flood it.
    static let categorizeCutoff = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 23))!

    /// A linked friend's expense where you have a share but haven't picked a group or skipped it.
    var needsCategorizing: Bool {
        guard friend?.linkedUserID != nil, group == nil, !groupDecided else { return false }
        return myShare > 0 && date >= Expense.categorizeCutoff
    }

    static func myShare(of amount: Decimal, splitType: SplitType, paidByMe: Bool) -> Decimal {
        switch splitType {
        case .equally:
            return amount / 2
        case .fullAmount:
            if paidByMe {
                return 0
            }
            return amount
        }
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

    /// Expenses dated within `interval`.
    func dated(in interval: DateInterval) -> [Expense] {
        filter { interval.contains($0.date) && $0.date < interval.end }
    }

    /// The full amount of every expense, regardless of who paid or how it's split.
    var totalAmount: Decimal {
        reduce(0) { $0 + $1.amount }
    }

    /// Your own part of these expenses (see `Expense.myShare`).
    var totalMyShare: Decimal {
        reduce(0) { $0 + $1.myShare }
    }
}
