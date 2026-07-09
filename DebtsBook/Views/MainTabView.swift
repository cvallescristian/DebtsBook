import SwiftUI
import SwiftData

struct MainTabView: View {

    var body: some View {
        TabView {
            Tab("Friends", systemImage: "person.2") {
                FriendView()
            }
            Tab("Expenses", systemImage: "dollarsign.circle") {
                ExpensesView()
            }
        }
    }
}


#Preview {
    MainTabView()
        .modelContainer(for: [Friend.self, Expense.self], inMemory: true)
}
