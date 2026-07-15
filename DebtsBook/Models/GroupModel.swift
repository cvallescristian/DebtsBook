import Foundation
import SwiftData

@Model
class ExpenseGroup {
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
