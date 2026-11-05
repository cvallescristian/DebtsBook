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

    static func track(_ context: ModelContext) {
        guard !isApplyingSyncChanges else { return }
        for case let model as any SyncedModel in context.insertedModelsArray + context.changedModelsArray {
            markDirty(model)
        }
        for case let model as any SyncedModel in context.deletedModelsArray {
            guard let remoteID = model.remoteID else { continue }
            context.insert(SyncTombstone(table: model.syncTable, remoteID: remoteID))
        }
    }

    /// ExpenseSyncService/ActivitySyncService treat a remoteID on a linked friend's row as
    /// "already on the server" (their reconcile pass deletes it if missing), so they keep
    /// assigning IDs for the shared tables themselves.
    static let sharedTables: Set<String> = ["expenses", "activities"]

    private static func markDirty(_ model: some SyncedModel) {
        if model.remoteID == nil && !sharedTables.contains(model.syncTable) {
            model.remoteID = UUID()
        }
        if !model.isDirty {
            model.isDirty = true
        }
    }
}
