
import SwiftUI
import SwiftData

struct ExpenseNewView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    @State private var title: String = ""
    @State private var amount: Decimal?
    @State private var paidByID: PersistentIdentifier?
    @State private var debtorID: PersistentIdentifier?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("What?") {
                    TextField("Title (e.g. Groceries)", text: $title)
                    TextField("Amount", value: $amount, format: .currency(code: "NZD"))
                        .keyboardType(.decimalPad)
                }
                Section("Who?"){
                    Picker("Paid by", selection: $paidByID) {
                        Text("Select").tag(nil as PersistentIdentifier?)
                        ForEach(friends) { friend in
                            Text(friend.name)
                                .tag(friend.persistentModelID as PersistentIdentifier?)
                        }
                    }
                    Picker("Owed by", selection: $paidByID) {
                        Text("Select").tag(nil as PersistentIdentifier?)
                        ForEach(friends) { friend in
                            Text(friend.name)
                                .tag(friend.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }
            }
            .navigationTitle(Text("New Expense"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
//                    .disabled(name.isEmpty)
                    .tint(.blue)
                }
            }
        }
    }
    
    private func save() {
//        let friend = Friend(name: name)
//        modelContext.insert(friend)
        dismiss()
    }
}


#Preview {
    ExpenseNewView()
}
