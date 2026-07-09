import SwiftUI

struct ActivityRow: View {

    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                if let resultText = activity.resultText {
                    Text(resultText)
                        .foregroundColor(activity.resultColor)
                }
                Text(activity.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


#Preview {
    List {
        ActivityRow(activity: Activity(type: .created, expenseTitle: "Groceries", friendName: "Ana", amount: 21.25, paidByMe: true))
        ActivityRow(activity: Activity(type: .paid, expenseTitle: "Movie tickets", friendName: "Ana", amount: 9, paidByMe: false))
        ActivityRow(activity: Activity(type: .settledUp, expenseTitle: "", friendName: "Ana", amount: 30, paidByMe: true))
        ActivityRow(activity: Activity(type: .deleted, expenseTitle: "Old expense", friendName: "Ana", amount: 5, paidByMe: true))
    }
}
