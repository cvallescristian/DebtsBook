import Foundation
import SwiftData
import SwiftUI

enum ActivityType: String, Codable {
    case created
    case updated
    case deleted
    case paid
    case settledUp
}

@Model
class Activity {
    var type: ActivityType = ActivityType.created
    var expenseTitle: String = ""
    var friendName: String?
    var amount: Decimal = 0
    var paidByMe: Bool = true
    var date: Date = Date()

    @Relationship(deleteRule: .nullify)
    var expense: Expense?

    @Relationship(deleteRule: .nullify)
    var friend: Friend?

    init(type: ActivityType, expenseTitle: String, friendName: String? = nil, amount: Decimal, paidByMe: Bool, expense: Expense? = nil, friend: Friend? = nil, date: Date = Date()) {
        self.type = type
        self.expenseTitle = expenseTitle
        self.friendName = friendName
        self.amount = amount
        self.paidByMe = paidByMe
        self.expense = expense
        self.friend = friend
        self.date = date
    }

    var icon: String {
        switch type {
        case .created: return "doc.text.fill"
        case .updated: return "pencil.circle.fill"
        case .deleted: return "trash.fill"
        case .paid, .settledUp: return "banknote.fill"
        }
    }

    var title: String {
        switch type {
        case .created:
            guard let friendName else { return "You added \u{201C}\(expenseTitle)\u{201D}." }
            return "You added \u{201C}\(expenseTitle)\u{201D} with \(friendName)."
        case .updated:
            guard let friendName else { return "You updated \u{201C}\(expenseTitle)\u{201D}." }
            return "You updated \u{201C}\(expenseTitle)\u{201D} with \(friendName)."
        case .deleted:
            guard let friendName else { return "You deleted \u{201C}\(expenseTitle)\u{201D}." }
            return "You deleted \u{201C}\(expenseTitle)\u{201D} with \(friendName)."
        case .paid: return paidByMe ? "\(friendName ?? "Friend") paid you." : "You paid \(friendName ?? "friend")."
        case .settledUp: return "You settled up with \(friendName ?? "friend")."
        }
    }

    var resultText: String? {
        let formattedAmount = amount.formatted(.currency(code: "NZD"))
        switch type {
        case .created, .updated:
            guard friendName != nil else { return "You spent \(formattedAmount)." }
            return paidByMe ? "You get back \(formattedAmount)." : "You owe \(formattedAmount)."
        case .paid:
            return paidByMe ? "\(friendName ?? "Friend") paid you \(formattedAmount)." : "You paid \(formattedAmount)."
        case .settledUp:
            return "All settled up."
        case .deleted:
            return nil
        }
    }

    var resultColor: Color {
        switch type {
        case .deleted:
            return .secondary
        case .paid, .settledUp:
            return .green
        case .created, .updated:
            guard friendName != nil else { return .secondary }
            return paidByMe ? .green : .orange
        }
    }
}
