
import SwiftUI
import SwiftData

struct ExpenseNewView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    @State private var title: String = ""
    @State private var amount: Decimal?
    @State private var friendID: PersistentIdentifier?
    @State private var paidByMe: Bool = true

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
            }
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
            }
        }
    }
    
    private func save() {
        guard let amount, let selectedFriend else { return }
        let expense = Expense(title: title, amount: amount, friend: selectedFriend, paidByMe: paidByMe)
        modelContext.insert(expense)
        dismiss()
    }
}


#Preview {
    ExpenseNewView()
        .modelContainer(PreviewSampleData.container)
}
