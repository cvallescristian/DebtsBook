import SwiftUI
import SwiftData

struct MainTabView: View {

    @Query private var pendingExpenses: [PendingExpense]
    @Query private var expenses: [Expense]

    private var expensesBadge: Int {
        pendingExpenses.count + expenses.filter(\.needsCategorizing).count
    }

    var body: some View {
        TabView {
            Tab("Friends", systemImage: "person.2") {
                FriendView()
            }
            Tab("Reports", systemImage: "chart.bar") {
                ReportsView()
            }
            Tab("Expenses", systemImage: "dollarsign.circle") {
                ExpensesView()
            }
            .badge(expensesBadge)
            Tab("Activity", systemImage: "clock.arrow.circlepath") {
                ActivityView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
    }
}


#Preview {
    MainTabView()
        .modelContainer(PreviewSampleData.container)
}
