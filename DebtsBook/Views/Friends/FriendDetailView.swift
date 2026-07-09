import SwiftUI
import SwiftData

struct FriendDetailView: View {

    let friend: Friend
    @State private var showingFriendEdit: Bool = false
    @State private var showingExpenseNew: Bool = false
    @State private var editingExpense: Expense?
    @State private var showingSettleUpConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [Expense]

    private var friendsExpenses: [Expense] {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .sorted { $0.date > $1.date }
    }

    private var balance: Decimal {
        friendsExpenses.netBalance
    }

    private var hasUnsettledExpenses: Bool {
        friendsExpenses.contains { !$0.isSettled }
    }

    var body: some View {
        List {
            VStack(spacing: 12) {
                HStack {
                    if balance > 0 {
                        Text("Overall, you are owed")
                            .font(.title2)
                        Text(balance, format: .currency(code: "NZD"))
                            .foregroundColor(.green)
                            .font(Font.title2.bold())
                    } else if balance < 0 {
                        Text("Overall, you owe")
                            .font(.title2)
                        Text(-balance, format: .currency(code: "NZD"))
                            .foregroundColor(.red)
                            .font(Font.title2.bold())
                    } else {
                        Label("Settled up", systemImage: "hand.thumbsup.fill")
                            .font(.title2)
                    }
                }

                if hasUnsettledExpenses {
                    Button("Settle Up") {
                        showingSettleUpConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)

            Section("Expenses") {
                ForEach(friendsExpenses) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                    .tint(.primary)
                    .settleSwipeAction(for: expense)
                }
            }
        }
        .confirmationDialog(
            "Settle up with \(friend.name)?",
            isPresented: $showingSettleUpConfirmation,
            titleVisibility: .visible
        ) {
            Button("Settle Up") {
                settleUp()
            }
        } message: {
            Text("This marks all of \(friend.name)'s expenses as paid.")
        }
        .navigationTitle(friend.name)
        .toolbar {
            Button {
                showingExpenseNew = true
            } label: {
                Image(systemName: "plus")
            }
            Button {
                showingFriendEdit = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
        .sheet(isPresented: $showingFriendEdit){
            FriendEditView(friend: friend, onDelete: { dismiss() })
        }
        .sheet(isPresented: $showingExpenseNew) {
            ExpenseNewView(friend: friend)
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }

    private func settleUp() {
        for expense in friendsExpenses where !expense.isSettled {
            expense.isSettled = true
        }
    }
}


#Preview {
    NavigationStack {
        FriendDetailView(friend: PreviewSampleData.friend)
    }
    .modelContainer(PreviewSampleData.container)
}
