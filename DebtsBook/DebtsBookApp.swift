import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {

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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    AuthService.shared.handle(url: url)
                }
        }
        .modelContainer(container)
    }
}
