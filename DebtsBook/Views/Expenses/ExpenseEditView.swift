import SwiftUI
import SwiftData

struct ExpenseEditView: View {

    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]
    @Query private var expenses: [Expense]
    @Query private var budgets: [Budget]

    @State private var title: String
    @State private var amount: Decimal?
    @State private var date: Date
    @State private var isPersonal: Bool
    @State private var friendID: PersistentIdentifier?
    @State private var groupID: PersistentIdentifier?
    @State private var paidByMe: Bool
    @State private var splitType: SplitType
    @State private var comment: String
    @State private var showingDeleteConfirmation: Bool = false
    @FocusState private var isInputFocused: Bool

    init(expense: Expense) {
        self.expense = expense
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: expense.amount)
        _date = State(initialValue: expense.date)
        _isPersonal = State(initialValue: expense.isPersonal)
        _friendID = State(initialValue: expense.friend?.persistentModelID)
        _groupID = State(initialValue: expense.group?.persistentModelID)
        _paidByMe = State(initialValue: expense.paidByMe)
        _splitType = State(initialValue: expense.splitType)
        _comment = State(initialValue: expense.comment ?? "")
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
        guard let amount, isPersonal else { return [] }
        return exceededBudgetWarnings(budgets: budgets, expenses: expenses, amount: amount, date: date, groupID: groupID, excluding: expense.persistentModelID)
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
                    Section("Group") {
                        Picker("Group", selection: $groupID) {
                            Text("None").tag(nil as PersistentIdentifier?)
                            ForEach(groups) { group in
                                Text(group.name)
                                    .tag(group.persistentModelID as PersistentIdentifier?)
                            }
                        }
                    }
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
                Section {
                    Button("Delete Expense", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete \(expense.title)?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete",
                successMessage: "Expense deleted",
                onConfirm: {
                    delete()
                },
                onDismiss: {
                    dismiss()
                }
            )
            .safeAreaInset(edge: .bottom) {
                Button("Save Changes") {
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
            .navigationTitle(Text("Edit Expense"))
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
        expense.title = title
        expense.amount = amount
        expense.date = date
        expense.friend = isPersonal ? nil : selectedFriend
        expense.group = isPersonal ? selectedGroup : nil
        expense.paidByMe = paidByMe
        expense.splitType = splitType
        expense.comment = trimmedComment.isEmpty ? nil : trimmedComment
        modelContext.insert(Activity(type: .updated, expenseTitle: expense.title, friendName: isPersonal ? nil : selectedFriend?.name, amount: expense.loggedAmount, paidByMe: expense.paidByMe, expense: expense, friend: isPersonal ? nil : selectedFriend))
        dismiss()
    }

    private func delete() {
        modelContext.insert(Activity(type: .deleted, expenseTitle: expense.title, friendName: expense.friend?.name, amount: expense.loggedAmount, paidByMe: expense.paidByMe, friend: expense.friend))
        modelContext.delete(expense)
    }
}


#Preview {
    ExpenseEditView(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true))
        .modelContainer(PreviewSampleData.container)
}
