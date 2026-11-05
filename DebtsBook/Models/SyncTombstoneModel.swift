import Foundation
import SwiftData

/// A local delete of a synced row, waiting to be pushed as `deleted_at` on the server.
/// Recorded by SyncChangeTracker, since a deleted model can't be read after the save.
@Model
class SyncTombstone {
    /// Supabase table the row lives in (e.g. "personal_expenses").
    var table: String = ""
    var remoteID: UUID = UUID()
    var date: Date = Date()

    init(table: String, remoteID: UUID, date: Date = Date()) {
        self.table = table
        self.remoteID = remoteID
        self.date = date
    }
}
