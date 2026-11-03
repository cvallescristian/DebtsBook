import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        // Under the unit test host, avoid touching the real on-disk store — and reuse the
        // single shared in-memory container the tests also use, since SwiftData traps if two
        // separate containers for the same @Model types are both alive in one process.
        let container: ModelContainer
        if TestModelContainer.isRunningTests {
            container = TestModelContainer.shared
        } else {
            container = try! ModelContainer(for: Friend.self, Expense.self, Activity.self, Budget.self, ExpenseGroup.self)
            DataIntegrityService.repairDanglingRelationships(context: container.mainContext)
        }
        self.container = container
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
