import SwiftUI
import SwiftData

struct ExpenseEditView: View {

    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Friend.name) private var friends: [Friend]

    @State private var title: String
    @State private var amount: Decimal?
    @State private var friendID: PersistentIdentifier?
    @State private var paidByMe: Bool
    @State private var showingDeleteConfirmation: Bool = false

    init(expense: Expense) {
        self.expense = expense
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: expense.amount)
        _friendID = State(initialValue: expense.friend?.persistentModelID)
        _paidByMe = State(initialValue: expense.paidByMe)
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
                Section("Who?") {
                    Picker("Friend", selection: $friendID) {
                        Text("Select").tag(nil as PersistentIdentifier?)
                        ForEach(friends) { friend in
                            Text(friend.name)
                                .tag(friend.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    if let selectedFriend {
                        VStack(alignment: .leading) {
                            Text("Who paid?")
                            Picker("Who paid?", selection: $paidByMe) {
                                Text("Me").tag(true)
                                Text(selectedFriend.name).tag(false)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }
                Section {
                    Button("Delete Expense", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .confirmationDialog(
                "Delete \(expense.title)?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
            } message: {
                Text("This action cannot be undone.")
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
        expense.title = title
        expense.amount = amount
        expense.friend = selectedFriend
        expense.paidByMe = paidByMe
        dismiss()
    }

    private func delete() {
        modelContext.delete(expense)
        dismiss()
    }
}


#Preview {
    ExpenseEditView(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true))
        .modelContainer(PreviewSampleData.container)
}
