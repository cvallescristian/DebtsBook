import SwiftUI
import SwiftData

struct FriendDetailView: View {

    let friend: Friend
    @State private var showingFriendEdit: Bool = false
    @State private var editingExpense: Expense?
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [Expense]

    private var friendsExpenses: [Expense] {
        expenses.filter { $0.friend?.persistentModelID == friend.persistentModelID }
    }

    private var balance: Decimal {
        friendsExpenses.netBalance
    }

    var body: some View {
        List {
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
        .navigationTitle(friend.name)
        .toolbar {
            Button {
                showingFriendEdit = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
        .sheet(isPresented: $showingFriendEdit){
            FriendEditView(friend: friend, onDelete: { dismiss() })
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }
}


#Preview {
    NavigationStack {
        FriendDetailView(friend: PreviewSampleData.friend)
    }
    .modelContainer(PreviewSampleData.container)
}
