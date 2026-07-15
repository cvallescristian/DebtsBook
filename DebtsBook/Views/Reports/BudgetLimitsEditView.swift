import SwiftUI
import SwiftData

struct BudgetLimitsEditView: View {

    let period: BudgetPeriod

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]
    @Query private var budgets: [Budget]

    @State private var globalAmount: Decimal?
    @State private var groupAmounts: [PersistentIdentifier: Decimal?] = [:]
    @FocusState private var focusedField: PersistentIdentifier?

    private var globalBudget: Budget? {
        budgets.first { $0.period == period && $0.group == nil }
    }

    private func existingBudget(for group: ExpenseGroup) -> Budget? {
        budgets.first { $0.period == period && $0.group?.persistentModelID == group.persistentModelID }
    }

    init(period: BudgetPeriod) {
        self.period = period
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Global \(period.rawValue)ly Limit") {
                    HStack {
                        TextField("Amount", value: $globalAmount, format: .currency(code: "NZD"))
                            .keyboardType(.decimalPad)

                        if globalBudget != nil {
                            Button(role: .destructive) {
                                if let globalBudget {
                                    modelContext.delete(globalBudget)
                                }
                                globalAmount = nil
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }

                if !groups.isEmpty {
                    Section("Group Limits") {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    TextField("No limit", value: groupBinding(for: group), format: .currency(code: "NZD"))
                                        .keyboardType(.decimalPad)
                                        .focused($focusedField, equals: group.persistentModelID)

                                    if existingBudget(for: group) != nil {
                                        Button(role: .destructive) {
                                            if let budget = existingBudget(for: group) {
                                                modelContext.delete(budget)
                                            }
                                            groupAmounts[group.persistentModelID] = nil
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("\(period.rawValue)ly Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                globalAmount = globalBudget?.amount
                for group in groups {
                    groupAmounts[group.persistentModelID] = existingBudget(for: group)?.amount
                }
            }
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
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func groupBinding(for group: ExpenseGroup) -> Binding<Decimal?> {
        Binding(
            get: { groupAmounts[group.persistentModelID] ?? nil },
            set: { groupAmounts[group.persistentModelID] = $0 }
        )
    }

    private func save() {
        if let globalAmount {
            if let existing = globalBudget {
                existing.amount = globalAmount
            } else {
                modelContext.insert(Budget(amount: globalAmount, period: period))
            }
        }

        for group in groups {
            let amount = groupAmounts[group.persistentModelID] ?? nil
            let existing = existingBudget(for: group)

            if let amount {
                if let existing {
                    existing.amount = amount
                } else {
                    modelContext.insert(Budget(amount: amount, period: period, group: group))
                }
            }
        }

        dismiss()
    }
}


#Preview {
    BudgetLimitsEditView(period: .week)
        .modelContainer(PreviewSampleData.container)
}
