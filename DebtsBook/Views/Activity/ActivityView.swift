import SwiftUI
import SwiftData

struct ActivityView: View {

    @Query(sort: \Activity.date, order: .reverse) private var activities: [Activity]

    var body: some View {
        NavigationStack {
            List {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .overlay {
                if activities.isEmpty {
                    ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath", description: Text("Changes you make to expenses will show up here."))
                }
            }
            .navigationTitle("Activity")
        }
    }
}


#Preview {
    ActivityView()
        .modelContainer(PreviewSampleData.container)
}
