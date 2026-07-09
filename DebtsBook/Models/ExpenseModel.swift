
import Foundation
import SwiftData

@Model
class Expense {
    var title: String
    var amount: Decimal
    var isSettled: Bool = false
    var createdAt: Date
    
    var paidBy: Friend?
    var debtor: Friend?
    
    init(name: String, amount: Decimal, paidBy: Friend, debtor: Friend) {
        self.title = name
        self.amount = amount
        self.paidBy = paidBy
        self.debtor = debtor
        self.createdAt = Date()
    }
}
