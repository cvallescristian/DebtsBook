import SwiftUI
import SwiftData

private enum FriendDetailTab: String, CaseIterable {
    case expenses = "Expenses"
    case activity = "Activity"
}

struct FriendDetailView: View {

    let friend: Friend
    @State private var selectedTab: FriendDetailTab = .expenses
    @State private var showingFriendEdit: Bool = false
    @State private var showingExpenseNew: Bool = false
    @State private var editingExpense: Expense?
    @State private var showingSettleUpConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var activities: [Activity]

    private var friendsExpenses: [Expense] {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .sorted { $0.date > $1.date }
    }

    private var friendsActivities: [Activity] {
        activities
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
            .listRowSeparator(.hidden)

            Picker("View", selection: $selectedTab) {
                ForEach(FriendDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            switch selectedTab {
            case .expenses:
                Section {
                    ForEach(friendsExpenses) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .tint(.primary)
                        .settleSwipeAction(for: expense, in: modelContext)
                    }
                }
            case .activity:
                Section {
                    ForEach(friendsActivities) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
        .overlay {
            switch selectedTab {
            case .expenses where friendsExpenses.isEmpty:
                ContentUnavailableView("No Expenses", systemImage: "dollarsign.circle", description: Text("Expenses with \(friend.name) will show up here."))
            case .activity where friendsActivities.isEmpty:
                ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath", description: Text("Changes you make will show up here."))
            default:
                EmptyView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingExpenseNew = true
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding()
        }
        .confirmationModal(
            isPresented: $showingSettleUpConfirmation,
            title: "Settle up with \(friend.name)?",
            message: "This marks all of \(friend.name)'s expenses as paid.",
            confirmLabel: "Settle Up",
            successMessage: "Settled up with \(friend.name)",
            isDestructive: false
        ) {
            settleUp()
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
        .sheet(isPresented: $showingExpenseNew) {
            ExpenseNewView(friend: friend)
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }

    private func settleUp() {
        let settledAmount = balance
        for expense in friendsExpenses where !expense.isSettled {
            expense.isSettled = true
        }
        modelContext.insert(Activity(type: .settledUp, expenseTitle: "", friendName: friend.name, amount: abs(settledAmount), paidByMe: settledAmount > 0, friend: friend))
    }
}


#Preview {
    NavigationStack {
        FriendDetailView(friend: PreviewSampleData.friend)
    }
    .modelContainer(PreviewSampleData.container)
}
