import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Friend.self, Expense.self])
    }
}
