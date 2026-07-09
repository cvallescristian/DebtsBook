import SwiftUI
import SwiftData

struct BudgetEditView: View {

    let period: BudgetPeriod
    let existingBudget: Budget?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal?

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
            }
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
}


#Preview {
    BudgetEditView(period: .week, existingBudget: nil)
        .modelContainer(PreviewSampleData.container)
}
