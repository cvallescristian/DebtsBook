import SwiftUI
import SwiftData

enum MainTab: Hashable {
    case friends, reports, expenses, activity, profile
}

struct MainTabView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var pendingExpenses: [PendingExpense]
    @State private var selectedTab: MainTab = .friends
    @State private var router = NotificationRouter.shared
    @State private var notifiedExpense: Expense?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Friends", systemImage: "person.2", value: MainTab.friends) {
                FriendView()
            }
            Tab("Reports", systemImage: "chart.bar", value: MainTab.reports) {
                ReportsView()
            }
            Tab("Expenses", systemImage: "dollarsign.circle", value: MainTab.expenses) {
                ExpensesView()
            }
            .badge(pendingExpenses.count)
            Tab("Activity", systemImage: "clock.arrow.circlepath", value: MainTab.activity) {
                ActivityView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
                ProfileView()
            }
        }
        .sheet(item: $notifiedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
        // A tap that cold-launches the app lands before this view exists, hence the initial run.
        .task(id: router.pendingRoute) {
            guard let route = router.pendingRoute else { return }
            router.pendingRoute = nil
            await open(route)
        }
    }

    private func open(_ route: NotificationRoute) async {
        switch route {
        case .friends:
            selectedTab = .friends
        case .activity:
            selectedTab = .activity
        case .expense(let remoteID):
            if let expense = expense(remoteID: remoteID) {
                notifiedExpense = expense
                return
            }
            // The push can arrive before this device has pulled the change.
            await SyncCoordinator.syncAll(into: modelContext)
            if let expense = expense(remoteID: remoteID) {
                notifiedExpense = expense
            } else {
                selectedTab = .activity
            }
        }
    }

    private func expense(remoteID: UUID) -> Expense? {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.remoteID == remoteID })
        return try? modelContext.fetch(descriptor).first
    }
}


#Preview {
    MainTabView()
        .modelContainer(PreviewSampleData.container)
}
