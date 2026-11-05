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
    private static var isSyncing = false
    private static let logger = Logger(subsystem: "Cristian.DebtsBook", category: "sync")

    static func syncAll(into context: ModelContext) async {
        guard let ownerID = AuthService.shared.syncUserID, !isSyncing else {
            logger.debug("Sync skipped (no confirmed owner or already syncing)")
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        let ownerSync = OwnerSyncService(backend: SupabaseSyncBackend(), context: context, ownerID: ownerID)
        // Push first so friends exist on the server before anything references them, and
        // local edits win over the pull that follows.
        do {
            try await ownerSync.push()
        } catch {
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
            logger.error("Owner pull failed: \(String(describing: error), privacy: .public)")
        }
        try? context.save()
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
