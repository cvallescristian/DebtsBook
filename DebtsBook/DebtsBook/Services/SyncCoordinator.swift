import Foundation
import SwiftData
import BackgroundTasks
import OSLog

enum SyncCoordinator {
    static let backgroundTaskID = "Cristian.DebtsBook.sync"

    /// Pulls friends first (it re-pushes history for newly linked friends), then every
    /// linked friend's expenses and activities.
    // Launch fires both the sign-in and the became-active triggers; overlapping pulls
    // would each insert the same new remote rows.
    private(set) static var isSyncing = false
    /// Set when a sync is requested while one is running, so changes made mid-sync still go out.
    private static var needsAnotherSync = false
    private static var scheduledSync: Task<Void, Never>?
    /// Edits close together go out as one sync.
    static let editDebounce: Duration = .seconds(2)
    private static let logger = Logger(subsystem: "Cristian.DebtsBook", category: "sync")

    static func syncAll(into context: ModelContext) async {
        guard let ownerID = AuthService.shared.syncUserID else {
            logger.debug("Sync skipped (no confirmed owner)")
            return
        }
        guard !isSyncing else {
            needsAnotherSync = true
            return
        }
        isSyncing = true
        // DataStore leaves saving to here: the save is what logs pending edits and deletes
        // (SyncChangeTracker), and doing it now rather than mid-action keeps lists stable.
        try? context.save()
        let status = SyncStatus.shared
        status.state = .syncing
        var failed = false
        let ownerSync = OwnerSyncService(backend: SupabaseSyncBackend(), context: context, ownerID: ownerID)
        // Push first so friends exist on the server before anything references them, and
        // local edits win over the pull that follows.
        do {
            try await ownerSync.push()
        } catch {
            failed = true
            if error is URLError {
                status.isOnline = false
            }
            logger.error("Owner push failed: \(String(describing: error), privacy: .public)")
        }
        await FriendSyncService.shared.pullFriends(into: context)

        let friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []
        for friend in friends where friend.linkedUserID != nil {
            await ExpenseSyncService.shared.pullExpenses(into: context, for: friend)
            await ActivitySyncService.shared.pullActivities(into: context, for: friend)
        }
        do {
            try await ownerSync.pull()
        } catch {
            failed = true
            logger.error("Owner pull failed: \(String(describing: error), privacy: .public)")
        }
        try? context.save()

        status.state = failed ? .failed : .idle
        if !failed {
            status.lastSyncedAt = Date()
            // Reaching the server proves we're online, even if NWPathMonitor missed the
            // network coming back (common in the simulator).
            status.isOnline = true
        }
        status.refreshPendingChanges(in: context)
        isSyncing = false
        if needsAnotherSync {
            needsAnotherSync = false
            await syncAll(into: context)
        }
    }

    /// Called after local edits: syncs once things settle instead of on every save.
    static func scheduleSync(in context: ModelContext) {
        SyncStatus.shared.refreshPendingChanges(in: context)
        guard AuthService.shared.syncUserID != nil else { return }
        scheduledSync?.cancel()
        scheduledSync = Task {
            try? await Task.sleep(for: editDebounce)
            guard !Task.isCancelled else { return }
            await syncAll(into: context)
        }
    }

    static func runBackgroundRefresh(container: ModelContainer) async {
        scheduleBackgroundRefresh()
        // A background launch starts with the session still being restored from the keychain.
        for _ in 0..<20 where AuthService.shared.isRestoringSession {
            try? await Task.sleep(for: .milliseconds(250))
        }
        await syncAll(into: container.mainContext)
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
