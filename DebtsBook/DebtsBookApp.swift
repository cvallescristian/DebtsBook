import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    AuthService.shared.handle(url: url)
                }
        }
        .modelContainer(for: [Friend.self, Expense.self, Activity.self, Budget.self, ExpenseGroup.self])
    }
}
