import SwiftUI
import SwiftData

struct ExpenseRow: View {

    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(expense.title)
                if let comment = expense.comment, !comment.isEmpty {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
                if expense.isPersonal {
                    Text(expense.amount, format: .currency(code: "NZD"))
                        .foregroundStyle(.secondary)
                } else {
                    Text(expense.signedAmount, format: .currency(code: "NZD").sign(strategy: .always()))
                        .foregroundColor(expense.paidByMe ? .green : .red)
                }
            }
            HStack {
                Text(expense.isPersonal ? "Personal" : expense.paidByLabel)
                Text(expense.date, format: .dateTime.day().month().year())
                    .foregroundStyle(.secondary)
                Spacer()
                if !expense.isPersonal {
                    Text(expense.isSettled ? "Paid" : "Unpaid")
                        .foregroundColor(expense.isSettled ? .green : .orange)
                }
            }
            .font(.caption)
        }
    }
}


extension View {
    @ViewBuilder
    func settleSwipeAction(for expense: Expense, in modelContext: ModelContext) -> some View {
        if expense.isPersonal {
            self
        } else {
            settleSwipeActionContent(for: expense, in: modelContext)
        }
    }

    private func settleSwipeActionContent(for expense: Expense, in modelContext: ModelContext) -> some View {
        swipeActions {
            Button {
                toggleSettled(for: expense, in: modelContext)
            } label: {
                Label(
                    expense.isSettled ? "Mark Unpaid" : "Mark Paid",
                    systemImage: expense.isSettled ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(expense.isSettled ? .orange : .green)
        }
    }
}

/// Toggles `isSettled` and keeps the Activity log in sync: marking paid logs a `.paid` entry,
/// marking unpaid again removes that same entry instead of logging a separate "unpaid" event.
private func toggleSettled(for expense: Expense, in modelContext: ModelContext) {
    let isConnected = expense.friend?.linkedUserID != nil
    if expense.isSettled {
        expense.isSettled = false
        let descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let activities = try? modelContext.fetch(descriptor),
           let lastPaidActivity = activities.first(where: { $0.type == .paid && $0.expense?.persistentModelID == expense.persistentModelID }) {
            let remoteID = lastPaidActivity.remoteID
            if isConnected, let remoteID {
                Task { await ActivitySyncService.shared.delete(remoteID: remoteID) }
            }
            modelContext.delete(lastPaidActivity)
        }
    } else {
        expense.isSettled = true
        let activity = Activity(type: .paid, expenseTitle: expense.title, friendName: expense.friend?.name, amount: expense.owedAmount, paidByMe: expense.paidByMe, expense: expense, friend: expense.friend)
        modelContext.insert(activity)
        if isConnected {
            Task { await ActivitySyncService.shared.push(activity: activity) }
        }
    }
    if isConnected {
        Task { await ExpenseSyncService.shared.push(expense: expense) }
    }
}


#Preview {
    List {
        ExpenseRow(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true, comment: "Split for the weekend BBQ"))
        ExpenseRow(expense: Expense(title: "Movie tickets", amount: 18, friend: PreviewSampleData.friend, paidByMe: false))
        ExpenseRow(expense: Expense(title: "Coffee", amount: 5.5))
    }
}
