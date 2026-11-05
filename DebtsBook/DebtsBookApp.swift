import SwiftUI
import SwiftData

/// The one container for the whole process, shared with App Intents that run in the background.
enum AppModelContainer {
    /// Every @Model type. All containers (app, tests, previews) build from this one list.
    static let modelTypes: [any PersistentModel.Type] = [
        Friend.self, Expense.self, Activity.self, Budget.self, ExpenseGroup.self, PendingExpense.self,
        SyncTombstone.self,
    ]

    static let shared: ModelContainer = {
        let container = makeContainer()
        SyncChangeTracker.start(observing: container.mainContext)
        return container
    }()

    private static func makeContainer() -> ModelContainer {
        // Under the unit test host, avoid touching the real on-disk store — and reuse the
        // single shared in-memory container the tests also use, since SwiftData traps if two
        // separate containers for the same @Model types are both alive in one process.
        if TestModelContainer.isRunningTests {
            return TestModelContainer.shared
        }
        if TestModelContainer.isUITesting {
            return TestModelContainer.makeUITestContainer()
        }
        let container = try! ModelContainer(for: Schema(modelTypes))
        DataIntegrityService.repairDanglingRelationships(context: container.mainContext)
        return container
    }
}

@main
struct DebtsBookApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        container = AppModelContainer.shared
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    AuthService.shared.handle(url: url)
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(SyncCoordinator.backgroundTaskID)) { [container] in
            await SyncCoordinator.runBackgroundRefresh(container: container)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await NotificationService.shared.save(deviceToken: deviceToken) }
    }
}
