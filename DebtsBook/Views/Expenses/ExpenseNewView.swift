
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

    init(friend: Friend? = nil) {
        _friendID = State(initialValue: friend?.persistentModelID)
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
        return exceededBudgetWarnings(budgets: budgets, expenses: expenses, amount: amount, date: date, groupID: groupID)
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
        let expense = Expense(title: title, amount: amount, friend: isPersonal ? nil : selectedFriend, group: isPersonal ? selectedGroup : nil, paidByMe: paidByMe, splitType: splitType, date: date, comment: trimmedComment.isEmpty ? nil : trimmedComment)
        modelContext.insert(expense)
        modelContext.insert(Activity(type: .created, expenseTitle: expense.title, friendName: isPersonal ? nil : selectedFriend?.name, amount: expense.loggedAmount, paidByMe: paidByMe, expense: expense, friend: isPersonal ? nil : selectedFriend))
        if expense.friend?.connectionID != nil {
            Task { await ExpenseSyncService.shared.push(expense: expense) }
        }
        dismiss()
    }
}


#Preview {
    ExpenseNewView()
        .modelContainer(PreviewSampleData.container)
}
