import Foundation
import SwiftData

/// The one door for user actions that change data. Every insert, delete or edit a screen
/// makes goes through here, which schedules a sync; the sync saves first (so
/// SyncChangeTracker logs the change as dirty or as a tombstone) and then uploads.
///
/// Saving is left to the sync a moment later on purpose: saving right after a delete
/// re-renders rows that still hold the deleted model and crashes on the first read.
///
/// CI (scripts/check-data-store.sh) fails if a view calls modelContext.insert/delete directly.
@MainActor
enum DataStore {

    static func insert(_ model: some PersistentModel, into context: ModelContext) {
        context.insert(model)
        commit(context)
    }

    static func delete(_ model: some PersistentModel, from context: ModelContext) {
        context.delete(model)
        commit(context)
    }

    /// Ends an action that only edited properties of existing models.
    static func commit(_ context: ModelContext) {
        SyncChangeTracker.markPendingChanges(in: context)
        SyncCoordinator.scheduleSync(in: context)
    }
}
