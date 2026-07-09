import SwiftUI
import SwiftData

struct ExpenseEditView: View {

    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Friend.name) private var friends: [Friend]

    @State private var title: String
    @State private var amount: Decimal?
    @State private var date: Date
    @State private var friendID: PersistentIdentifier?
    @State private var paidByMe: Bool
    @State private var splitType: SplitType
    @State private var comment: String
    @State private var showingDeleteConfirmation: Bool = false

    init(expense: Expense) {
        self.expense = expense
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: expense.amount)
        _date = State(initialValue: expense.date)
        _friendID = State(initialValue: expense.friend?.persistentModelID)
        _paidByMe = State(initialValue: expense.paidByMe)
        _splitType = State(initialValue: expense.splitType)
        _comment = State(initialValue: expense.comment ?? "")
    }

    private var selectedFriend: Friend? {
        friends.first { $0.persistentModelID == friendID }
    }

    private var isSaveDisabled: Bool {
        title.isEmpty || amount == nil || friendID == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What?") {
                    TextField("Title (e.g. Groceries)", text: $title)
                    TextField("Amount", value: $amount, format: .currency(code: "NZD"))
                        .keyboardType(.decimalPad)
                }
                Section("When?") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
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
                Section("Comment") {
                    TextField("Optional comment", text: $comment, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                }
                Section {
                    Button("Delete Expense", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete \(expense.title)?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete"
            ) {
                delete()
            }
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
            }
        }
    }

    private func save() {
        guard let amount, let selectedFriend else { return }
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.title = title
        expense.amount = amount
        expense.date = date
        expense.friend = selectedFriend
        expense.paidByMe = paidByMe
        expense.splitType = splitType
        expense.comment = trimmedComment.isEmpty ? nil : trimmedComment
        modelContext.insert(Activity(type: .updated, expenseTitle: expense.title, friendName: selectedFriend.name, amount: expense.owedAmount, paidByMe: expense.paidByMe, expense: expense, friend: selectedFriend))
        dismiss()
    }

    private func delete() {
        modelContext.insert(Activity(type: .deleted, expenseTitle: expense.title, friendName: expense.friend?.name ?? "", amount: expense.owedAmount, paidByMe: expense.paidByMe, friend: expense.friend))
        modelContext.delete(expense)
        dismiss()
    }
}


#Preview {
    ExpenseEditView(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true))
        .modelContainer(PreviewSampleData.container)
}
