import SwiftUI
import SwiftData

struct ExpenseDetailView: View {

    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false

    /// Deleting from the edit sheet leaves this view holding a removed model.
    private var isGone: Bool {
        expense.isDeleted || expense.modelContext == nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if isGone {
                    Color.clear
                } else {
                    content
                }
            }
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEdit = true
                    }
                    .disabled(isGone)
                }
            }
            .sheet(isPresented: $showingEdit, onDismiss: {
                if isGone {
                    dismiss()
                }
            }) {
                ExpenseEditView(expense: expense)
            }
        }
    }

    private var content: some View {
        List {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            if let friend = expense.friend {
                Section("Split") {
                    LabeledContent("With", value: friend.name)
                    LabeledContent("Paid by", value: expense.paidByMe ? "You" : friend.name)
                    LabeledContent("Split", value: expense.splitType == .equally ? "Equally" : "Full amount")
                    LabeledContent(expense.paidByMe ? "\(friend.name) owes you" : "You owe \(friend.name)") {
                        Text(expense.owedAmount, format: .currency(code: "NZD"))
                            .foregroundStyle(expense.paidByMe ? .green : .red)
                    }
                    LabeledContent("Your share") {
                        Text(expense.myShare, format: .currency(code: "NZD"))
                    }
                }
            }
            Section("Details") {
                LabeledContent("Date") {
                    Text(expense.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                }
                if let group = expense.group {
                    LabeledContent("Group") {
                        HStack(spacing: 8) {
                            GroupIcon(group: group, size: 24)
                            Text(group.name)
                        }
                    }
                }
                if let comment = expense.comment, !comment.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(comment)
                    }
                }
            }
            if !expense.isPersonal {
                Section {
                    Button {
                        toggleSettled(for: expense, in: modelContext)
                    } label: {
                        Label(
                            expense.isSettled ? "Mark Unpaid" : "Mark Paid",
                            systemImage: expense.isSettled ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    .tint(expense.isSettled ? .orange : .green)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(expense.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(expense.amount, format: .currency(code: "NZD"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            HStack(spacing: 8) {
                Text(expense.isPersonal ? "Personal" : expense.paidByLabel)
                    .foregroundStyle(.secondary)
                SyncIcon(item: expense)
            }
            .font(.subheadline)
            if !expense.isPersonal {
                statusBadge
            }
        }
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        let color: Color = expense.isSettled ? .green : .orange
        return Label(
            expense.isSettled ? "Paid" : "Unpaid",
            systemImage: expense.isSettled ? "checkmark.circle.fill" : "clock.fill"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
        .accessibilityIdentifier("expenseStatusBadge")
    }
}


#Preview {
    ExpenseDetailView(expense: Expense(title: "Groceries", amount: 42.50, friend: PreviewSampleData.friend, paidByMe: true, comment: "Split for the weekend BBQ"))
        .modelContainer(PreviewSampleData.container)
}
