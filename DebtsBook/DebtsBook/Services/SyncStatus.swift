import Foundation
import SwiftData
import Network

/// What the Profile screen shows about sync: whether data is backed up to the account,
/// syncing, waiting for a connection, or failing.
@Observable
final class SyncStatus {
    static let shared = SyncStatus()

    enum State: Equatable {
        case idle
        case syncing
        case failed
    }

    var state: State = .idle
    var lastSyncedAt: Date?
    /// Local changes not yet on the server (dirty rows + tombstones).
    var pendingChanges = 0
    var isOnline = true

    private let monitor = NWPathMonitor()

    private init() {}

    /// Watches connectivity; `onReconnect` runs when the network comes back.
    func startMonitoring(onReconnect: @escaping @MainActor () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let reconnected = online && !self.isOnline
                self.isOnline = online
                if reconnected {
                    onReconnect()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "Cristian.DebtsBook.network"))
    }

    func refreshPendingChanges(in context: ModelContext) {
        pendingChanges = Self.countPending(in: context)
    }

    static func countPending(in context: ModelContext) -> Int {
        let dirty = [
            (try? context.fetchCount(FetchDescriptor<Friend>(predicate: #Predicate { $0.isDirty }))) ?? 0,
            (try? context.fetchCount(FetchDescriptor<ExpenseGroup>(predicate: #Predicate { $0.isDirty }))) ?? 0,
            (try? context.fetchCount(FetchDescriptor<Budget>(predicate: #Predicate { $0.isDirty }))) ?? 0,
            (try? context.fetchCount(FetchDescriptor<Expense>(predicate: #Predicate { $0.isDirty }))) ?? 0,
            (try? context.fetchCount(FetchDescriptor<Activity>(predicate: #Predicate { $0.isDirty }))) ?? 0,
        ].reduce(0, +)
        let tombstones = (try? context.fetchCount(FetchDescriptor<SyncTombstone>())) ?? 0
        return dirty + tombstones
    }

    struct Summary: Equatable {
        let text: String
        let systemImage: String
        let isWarning: Bool
    }

    static func summary(isSignedIn: Bool, state: State, isOnline: Bool, pendingChanges: Int, lastSyncedAt: Date?, now: Date = Date()) -> Summary {
        guard isSignedIn else {
            return Summary(text: "Only on this iPhone", systemImage: "iphone", isWarning: false)
        }
        let waiting = pendingChanges == 1 ? "1 change waiting" : "\(pendingChanges) changes waiting"
        if !isOnline {
            if pendingChanges > 0 {
                return Summary(text: "Offline · \(waiting)", systemImage: "icloud.slash", isWarning: true)
            }
            return Summary(text: "Offline", systemImage: "icloud.slash", isWarning: true)
        }
        if state == .syncing {
            return Summary(text: "Syncing…", systemImage: "arrow.triangle.2.circlepath.icloud", isWarning: false)
        }
        if state == .failed {
            return Summary(text: "Couldn't sync · will retry", systemImage: "exclamationmark.icloud", isWarning: true)
        }
        if pendingChanges > 0 {
            return Summary(text: waiting, systemImage: "icloud.and.arrow.up", isWarning: false)
        }
        guard let lastSyncedAt else {
            return Summary(text: "Saved to your account", systemImage: "checkmark.icloud", isWarning: false)
        }
        let ago = lastSyncedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        let text = now.timeIntervalSince(lastSyncedAt) < 60 ? "Synced just now" : "Synced \(ago)"
        return Summary(text: text, systemImage: "checkmark.icloud", isWarning: false)
    }
}
