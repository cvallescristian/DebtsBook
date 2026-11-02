import Foundation
import SwiftData
import BackgroundTasks

enum SyncCoordinator {
    static let backgroundTaskID = "Cristian.DebtsBook.sync"

    /// Pulls friends first (it re-pushes history for newly linked friends), then every
    /// linked friend's expenses and activities.
    // Launch fires both the sign-in and the became-active triggers; overlapping pulls
    // would each insert the same new remote rows.
    private static var isSyncing = false

    static func syncAll(into context: ModelContext) async {
        guard AuthService.shared.isSignedIn, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await FriendSyncService.shared.pullFriends(into: context)

        let friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []
        for friend in friends where friend.linkedUserID != nil {
            await ExpenseSyncService.shared.pullExpenses(into: context, for: friend)
            await ActivitySyncService.shared.pullActivities(into: context, for: friend)
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
