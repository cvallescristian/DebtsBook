import SwiftUI
import SwiftData

struct BudgetEditView: View {

    let period: BudgetPeriod
    let existingBudget: Budget?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal?
    @State private var showingDeleteConfirmation: Bool = false
    @FocusState private var isInputFocused: Bool

    init(period: BudgetPeriod, existingBudget: Budget?) {
        self.period = period
        self.existingBudget = existingBudget
        _amount = State(initialValue: existingBudget?.amount)
    }

    private var isSaveDisabled: Bool {
        amount == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .currency(code: "NZD"))
                    .keyboardType(.decimalPad)
                    .focused($isInputFocused)

                if existingBudget != nil {
                    Section {
                        Button("Delete Budget", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
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
                    .disabled(isSaveDisabled)
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
        } else {
            modelContext.insert(Budget(amount: amount, period: period))
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
