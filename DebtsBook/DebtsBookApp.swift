import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {

    private let container: ModelContainer

    init() {
        let container = try! ModelContainer(for: Friend.self, Expense.self, Activity.self, Budget.self, ExpenseGroup.self)
        DataIntegrityService.repairDanglingRelationships(context: container.mainContext)
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
