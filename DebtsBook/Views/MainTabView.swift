import SwiftUI
import SwiftData

struct MainTabView: View {

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
