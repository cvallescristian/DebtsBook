import Foundation
import SwiftData

@Model
class ExpenseGroup {
    var name: String = ""
    var createdAt: Date = Date()
    /// SF Symbol shown for the group; nil means no icon (the initial is shown instead).
    var iconName: String?
    /// One of `GroupStyle.colorNames`; nil for groups made before colours existed.
    var colorName: String?
    var remoteID: UUID?
    /// Changed locally since the last push (set by SyncChangeTracker).
    var isDirty: Bool = false

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
