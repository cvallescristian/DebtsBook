import SwiftUI

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
                Text(expense.signedAmount, format: .currency(code: "NZD").sign(strategy: .always()))
                    .foregroundColor(expense.paidByMe ? .green : .red)
            }
            HStack {
                Text(expense.paidByLabel)
                Text(expense.date, format: .dateTime.day().month().year())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(expense.isSettled ? "Paid" : "Unpaid")
                    .foregroundColor(expense.isSettled ? .green : .orange)
            }
            .font(.caption)
        }
    }
}


extension View {
    func settleSwipeAction(for expense: Expense) -> some View {
        swipeActions {
            Button {
                expense.isSettled.toggle()
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


#Preview {
    List {
        ExpenseRow(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true, comment: "Split for the weekend BBQ"))
        ExpenseRow(expense: Expense(title: "Movie tickets", amount: 18, friend: PreviewSampleData.friend, paidByMe: false))
    }
}
