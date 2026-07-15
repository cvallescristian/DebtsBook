import SwiftUI
import SwiftData

struct BudgetEditView: View {

    let period: BudgetPeriod
    let existingBudget: Budget?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]
    @Query private var budgets: [Budget]

    @State private var amount: Decimal?
    @State private var groupID: PersistentIdentifier?
    @State private var showingDeleteConfirmation: Bool = false
    @FocusState private var isInputFocused: Bool

    init(period: BudgetPeriod, existingBudget: Budget?, group: ExpenseGroup? = nil) {
        self.period = period
        self.existingBudget = existingBudget
        _amount = State(initialValue: existingBudget?.amount)
        _groupID = State(initialValue: group?.persistentModelID ?? existingBudget?.group?.persistentModelID)
    }

    private var selectedGroup: ExpenseGroup? {
        groups.first { $0.persistentModelID == groupID }
    }

    private var isSaveDisabled: Bool {
        amount == nil
    }

    private var hasDuplicateBudget: Bool {
        guard existingBudget == nil else { return false }
        return budgets.contains { budget in
            budget.period == period &&
            budget.group?.persistentModelID == groupID
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount", value: $amount, format: .currency(code: "NZD"))
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }

                if !groups.isEmpty {
                    Section("Group") {
                        Picker("Group", selection: $groupID) {
                            Text("All (Global)").tag(nil as PersistentIdentifier?)
                            ForEach(groups) { group in
                                Text(group.name).tag(group.persistentModelID as PersistentIdentifier?)
                            }
                        }
                    }
                }

                if hasDuplicateBudget {
                    Section {
                        Label("A \(period.rawValue.lowercased())ly budget already exists for this group.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }

                if existingBudget != nil {
                    Section {
                        Button("Delete Budget", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete this budget?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete",
                successMessage: "Budget deleted",
                onConfirm: {
                    delete()
                },
                onDismiss: {
                    dismiss()
                }
            )
            .navigationTitle("\(period.rawValue)ly Budget")
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
                    .disabled(isSaveDisabled || hasDuplicateBudget)
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
        if let existingBudget {
            existingBudget.amount = amount
            existingBudget.group = selectedGroup
        } else {
            modelContext.insert(Budget(amount: amount, period: period, group: selectedGroup))
        }
        dismiss()
    }

    private func delete() {
        guard let existingBudget else { return }
        modelContext.delete(existingBudget)
    }
}


#Preview {
    BudgetEditView(period: .week, existingBudget: nil)
        .modelContainer(PreviewSampleData.container)
}
