
import SwiftUI
import SwiftData

struct ExpenseNewView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]
    @Query private var expenses: [Expense]
    @Query private var budgets: [Budget]

    @State private var title: String = ""
    @State private var amount: Decimal?
    @State private var date: Date = Date()
    @State private var isPersonal: Bool = false
    @State private var friendID: PersistentIdentifier?
    @State private var groupID: PersistentIdentifier?
    @State private var paidByMe: Bool = true
    @State private var splitType: SplitType = .equally
    @State private var comment: String = ""
    @FocusState private var isInputFocused: Bool

    private let pending: PendingExpense?

    init(friend: Friend? = nil, pending: PendingExpense? = nil) {
        self.pending = pending
        _friendID = State(initialValue: friend?.persistentModelID)
        _isPersonal = State(initialValue: friend == nil)
        if let pending {
            _title = State(initialValue: pending.merchant)
            _amount = State(initialValue: pending.amount)
            _date = State(initialValue: pending.date)
        }
    }

    private var selectedGroup: ExpenseGroup? {
        groups.first { $0.persistentModelID == groupID }
    }

    private var selectedFriend: Friend? {
        friends.first { $0.persistentModelID == friendID }
    }

    private var isSaveDisabled: Bool {
        title.isEmpty || amount == nil || (!isPersonal && friendID == nil)
    }

    private var budgetWarnings: [String] {
        guard let spendingAmount else { return [] }
        return exceededBudgetWarnings(budgets: budgets, expenses: expenses, amount: spendingAmount, date: date, groupID: groupID)
    }

    private var sharedShare: Decimal {
        Expense.myShare(of: amount ?? 0, splitType: splitType, paidByMe: paidByMe)
    }

    /// What this expense would add to Reports and budgets, or nil if it doesn't count there.
    private var spendingAmount: Decimal? {
        guard let amount else { return nil }
        if isPersonal {
            return amount
        }
        guard groupID != nil, sharedShare > 0 else { return nil }
        return sharedShare
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What?") {
                    TextField("Title (e.g. Groceries)", text: $title)
                        .focused($isInputFocused)
                    TextField("Amount", value: $amount, format: .currency(code: "NZD"))
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }
                Section("When?") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Picker("Kind", selection: $isPersonal) {
                        Text("With a Friend").tag(false)
                        Text("Just Me").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                if isPersonal && !groups.isEmpty {
                    ExpenseGroupSection(groups: groups, groupID: $groupID, sharedShare: nil)
                }
                if !isPersonal {
                    Section("Who?") {
                        Picker("Friend", selection: $friendID) {
                            Text("Select").tag(nil as PersistentIdentifier?)
                            ForEach(friends) { friend in
                                Text(friend.name)
                                    .tag(friend.persistentModelID as PersistentIdentifier?)
                            }
                        }
                    }
                    if let selectedFriend {
                        Section("How was this expense split?") {
                            SplitOptionsPicker(
                                amount: amount ?? 0,
                                friendName: selectedFriend.name,
                                paidByMe: $paidByMe,
                                splitType: $splitType
                            )
                        }
                        if !groups.isEmpty {
                            ExpenseGroupSection(groups: groups, groupID: $groupID, sharedShare: sharedShare)
                        }
                    }
                }
                Section("Comment") {
                    TextField("Optional comment", text: $comment, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .focused($isInputFocused)
                }
                if !budgetWarnings.isEmpty {
                    Section {
                        ForEach(budgetWarnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button("Create Expense") {
                    save()
                }
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSaveDisabled)
                .padding()
            }
            .navigationTitle(Text("New Expense"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        guard isPersonal || selectedFriend != nil else { return }
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(title: title, amount: amount, friend: isPersonal ? nil : selectedFriend, group: selectedGroup, paidByMe: paidByMe, splitType: splitType, date: date, comment: trimmedComment.isEmpty ? nil : trimmedComment)
        if expense.friend?.linkedUserID != nil {
            expense.groupDecided = true
            expense.groupNeedsSync = true
        }
        DataStore.insert(expense, into: modelContext)
        let activity = Activity(type: .created, expenseTitle: expense.title, friendName: isPersonal ? nil : selectedFriend?.name, amount: expense.loggedAmount, paidByMe: paidByMe, expense: expense, friend: isPersonal ? nil : selectedFriend)
        DataStore.insert(activity, into: modelContext)
        if let pending {
            DataStore.delete(pending, from: modelContext)
        }
        if expense.friend?.linkedUserID != nil {
            Task { await ExpenseSyncService.shared.push(expense: expense) }
            Task { await ActivitySyncService.shared.push(activity: activity) }
        }
        dismiss()
    }
}


#Preview {
    ExpenseNewView()
        .modelContainer(PreviewSampleData.container)
}
