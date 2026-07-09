import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .modelContainer(for: [Friend.self, Expense.self])
    }
}
