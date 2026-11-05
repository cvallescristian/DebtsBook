import Foundation
import SwiftData

@Model
class ExpenseGroup {
    var name: String = ""
    var createdAt: Date = Date()
    var remoteID: UUID?
    /// Changed locally since the last push (set by SyncChangeTracker).
    var isDirty: Bool = false

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
