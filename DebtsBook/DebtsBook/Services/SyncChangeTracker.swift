import Foundation
import SwiftData

/// A model that syncs to a Supabase table by `remoteID`.
protocol SyncedModel: PersistentModel {
    var remoteID: UUID? { get set }
    var isDirty: Bool { get set }
    /// The table this row belongs in right now. Expenses and activities move between the
    /// owner-only and connection-shared tables when their friend links or unlinks.
    var syncTable: String { get }
}

extension Friend: SyncedModel {
    var syncTable: String { "friends" }
}

extension ExpenseGroup: SyncedModel {
    var syncTable: String { "expense_groups" }
}

extension Budget: SyncedModel {
    var syncTable: String { "budgets" }
}

extension Expense: SyncedModel {
    var syncTable: String { friend?.linkedUserID == nil ? "personal_expenses" : "expenses" }
}

extension SyncedModel {
    /// On the server as it is locally. Shared rows count once uploaded (their services push
    /// every change immediately); owner rows also need no unpushed edits.
    var isSynced: Bool {
        guard remoteID != nil else { return false }
        if SyncChangeTracker.sharedTables.contains(syncTable) {
            return true
        }
        return !isDirty
    }
}

extension Activity: SyncedModel {
    var syncTable: String { friend?.linkedUserID == nil ? "personal_activities" : "activities" }
}

/// Tracks local changes in one place, so views don't have to: every save marks inserted
/// and changed synced rows dirty (giving new ones a remoteID) and records deletes as
/// SyncTombstones. Runs signed in or not, so local-mode edits upload after sign-in.
@MainActor
enum SyncChangeTracker {

    /// Set while sync itself writes (applying pulled rows, clearing isDirty after a push),
    /// so those writes don't count as local edits.
    static var isApplyingSyncChanges = false

    private static var observer: NSObjectProtocol?

    static func start(observing context: ModelContext) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: context, queue: nil) { _ in
            MainActor.assumeIsolated {
                track(context)
            }
        }
    }

    /// Runs `body` and saves without marking anything dirty.
    static func applyingSyncChanges(in context: ModelContext, _ body: () throws -> Void) rethrows {
        isApplyingSyncChanges = true
        defer { isApplyingSyncChanges = false }
        try body()
        try? context.save()
    }

    /// Marks unsaved inserts and edits dirty right away (no save), so rows show "waiting to
    /// sync" as soon as the user acts. Deletes still become tombstones at save time.
    static func markPendingChanges(in context: ModelContext) {
        for case let model as any SyncedModel in context.insertedModelsArray + context.changedModelsArray {
            markDirty(model)
        }
    }

    static func track(_ context: ModelContext) {
        guard !isApplyingSyncChanges else { return }
        var changed = false
        for case let model as any SyncedModel in context.insertedModelsArray + context.changedModelsArray {
            markDirty(model)
            changed = true
        }
        for case let model as any SyncedModel in context.deletedModelsArray {
            changed = true
            guard let remoteID = model.remoteID else { continue }
            context.insert(SyncTombstone(table: model.syncTable, remoteID: remoteID))
        }
        // Saves during a sync (its own pulled updates) must not schedule another one, or
        // every sync triggers the next. Edits made meanwhile stay dirty for the next sync.
        if changed && !SyncCoordinator.isSyncing {
            // After this save completes, so the sync reads committed data.
            Task { @MainActor in
                SyncCoordinator.scheduleSync(in: context)
            }
        }
    }

    /// ExpenseSyncService/ActivitySyncService treat a remoteID on a linked friend's row as
    /// "already on the server" (their reconcile pass deletes it if missing), so they keep
    /// assigning IDs for the shared tables themselves.
    static let sharedTables: Set<String> = ["expenses", "activities"]

    private static func markDirty(_ model: some SyncedModel) {
        // Shared rows are pushed by their own services as they change, so they're never
        // "waiting": leaving them dirty would count them as pending forever.
        if sharedTables.contains(model.syncTable) {
            if model.isDirty {
                model.isDirty = false
            }
            return
        }
        if model.remoteID == nil {
            model.remoteID = UUID()
        }
        if !model.isDirty {
            model.isDirty = true
        }
    }
}
