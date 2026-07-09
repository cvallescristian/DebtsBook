
import SwiftUI
import SwiftData

struct ExpenseNewView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    @State private var title: String = ""
    @State private var amount: Decimal?
    @State private var date: Date = Date()
    @State private var isPersonal: Bool = false
    @State private var friendID: PersistentIdentifier?
    @State private var paidByMe: Bool = true
    @State private var splitType: SplitType = .equally
    @State private var comment: String = ""

    init(friend: Friend? = nil) {
        _friendID = State(initialValue: friend?.persistentModelID)
    }

    private var selectedFriend: Friend? {
        friends.first { $0.persistentModelID == friendID }
    }

    private var isSaveDisabled: Bool {
        title.isEmpty || amount == nil || (!isPersonal && friendID == nil)
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
                Section {
                    Picker("Kind", selection: $isPersonal) {
                        Text("With a Friend").tag(false)
                        Text("Just Me").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
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
        guard let amount else { return }
        guard isPersonal || selectedFriend != nil else { return }
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(title: title, amount: amount, friend: isPersonal ? nil : selectedFriend, paidByMe: paidByMe, splitType: splitType, date: date, comment: trimmedComment.isEmpty ? nil : trimmedComment)
        modelContext.insert(expense)
        modelContext.insert(Activity(type: .created, expenseTitle: expense.title, friendName: isPersonal ? nil : selectedFriend?.name, amount: expense.owedAmount, paidByMe: paidByMe, expense: expense, friend: isPersonal ? nil : selectedFriend))
        dismiss()
    }
}


#Preview {
    ExpenseNewView()
        .modelContainer(PreviewSampleData.container)
}
