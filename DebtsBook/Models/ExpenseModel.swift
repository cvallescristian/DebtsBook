
import Foundation
import SwiftData

@Model
class Expense {
    var title: String
    var amount: Decimal
    var isSettled: Bool = false
    var createdAt: Date
    
    var friend: Friend?
    var paidByMe: Bool

    init(title: String, amount: Decimal, friend: Friend, paidByMe: Bool) {
        self.title = title
        self.amount = amount
        self.friend = friend
        self.paidByMe = paidByMe
        self.createdAt = Date()
    }
}
