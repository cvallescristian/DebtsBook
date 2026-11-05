import Testing
import Foundation
@testable import DebtsBook

struct SyncStatusTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func summary(signedIn: Bool = true, state: SyncStatus.State = .idle, online: Bool = true, pending: Int = 0, last: Date? = nil) -> SyncStatus.Summary {
        SyncStatus.summary(isSignedIn: signedIn, state: state, isOnline: online, pendingChanges: pending, lastSyncedAt: last, now: now)
    }

    @Test func signedOutDataStaysOnThePhone() {
        #expect(summary(signedIn: false, pending: 3).text == "Only on this iPhone")
    }

    @Test func offlineShowsWaitingChanges() {
        let result = summary(online: false, pending: 2)
        #expect(result.text == "Offline · 2 changes waiting")
        #expect(result.isWarning)
    }

    @Test func singularChange() {
        #expect(summary(pending: 1).text == "1 change waiting")
    }

    @Test func syncingAndFailed() {
        #expect(summary(state: .syncing).text == "Syncing…")
        #expect(summary(state: .failed).isWarning)
    }

    @Test func recentSyncSaysJustNow() {
        #expect(summary(last: now.addingTimeInterval(-10)).text == "Synced just now")
    }

    @Test func pullCursorIsAFullTimestamp() {
        let date = Date(timeIntervalSince1970: 1_793_872_740.5)
        #expect(SupabaseSyncBackend.timestamp(date) == "2026-11-05T09:59:00.500Z")
    }

    @Test func olderSyncShowsRelativeTime() {
        let text = summary(last: now.addingTimeInterval(-300)).text
        #expect(text.hasPrefix("Synced ") && text != "Synced just now")
    }
}
