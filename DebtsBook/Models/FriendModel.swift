import Foundation
import SwiftData

@Model
class Friend {
    var name: String = ""
    var createdAt: Date = Date()
    var remoteID: UUID?
    /// Changed locally since the last push (set by SyncChangeTracker).
    var isDirty: Bool = false
    var linkedUserID: UUID?
    var connectionID: UUID?
    @Attribute(.externalStorage) var photoData: Data?
    var iconName: String?
    var lastSyncedAt: Date?

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
