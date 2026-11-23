import SwiftUI
import SwiftData

/// Edits every budget at once: the overall weekly/monthly/yearly limits and each group's,
/// and lets groups be added, edited and deleted without leaving the screen.
/// With `group` set, it shows only that group's limits.
struct BudgetLimitsEditView: View {

    var group: ExpenseGroup?
    /// The period whose field gets focus on open.
    var focusPeriod: BudgetPeriod?

    private struct BudgetKey: Hashable {
        let groupID: PersistentIdentifier?
        let period: BudgetPeriod
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]
    @Query private var budgets: [Budget]
    @Query private var expenses: [Expense]

    @State private var amounts: [BudgetKey: Decimal?] = [:]
    @State private var showingNewGroup = false
    @State private var editingGroup: ExpenseGroup?
    @State private var deletingGroup: ExpenseGroup?
    @FocusState private var focusedField: BudgetKey?

    private var visibleGroups: [ExpenseGroup] {
        guard let group else { return groups }
        return groups.filter { $0.persistentModelID == group.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if group == nil {
                    Section {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            amountRow(BudgetKey(groupID: nil, period: period))
                        }
                    } header: {
                        Text("Overall Budget")
                    } footer: {
                        Text("Covers all personal expenses (\"Just Me\").")
                    }
                }

                ForEach(visibleGroups) { group in
                    Section {
                        Button {
                            editingGroup = group
                        } label: {
                            HStack(spacing: 12) {
                                GroupIcon(group: group)
                                Text(group.name)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                        .accessibilityHint("Edit name, icon and colour")
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deletingGroup = group
                            }
                        }

                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            amountRow(BudgetKey(groupID: group.persistentModelID, period: period))
                        }
                    }
                }

                if group == nil {
                    Section {
                        Button {
                            showingNewGroup = true
                        } label: {
                            Label("Add Group", systemImage: "plus.circle.fill")
                        }
                    } footer: {
                        Text("Leave a limit empty for no limit.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(group.map { "\($0.name) Budget" } ?? "Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMissingAmounts()
                if let focusPeriod {
                    focusedField = BudgetKey(groupID: group?.persistentModelID, period: focusPeriod)
                }
            }
            .onChange(of: groups.map(\.persistentModelID)) {
                loadMissingAmounts()
            }
            .sheet(isPresented: $showingNewGroup) {
                GroupNewView()
            }
            .sheet(item: $editingGroup) { group in
                GroupEditView(group: group)
            }
            .confirmationDialog(
                "Delete \(deletingGroup?.name ?? "Group")?",
                isPresented: Binding(get: { deletingGroup != nil }, set: { if !$0 { deletingGroup = nil } }),
                titleVisibility: .visible,
                presenting: deletingGroup
            ) { group in
                Button("Delete Group", role: .destructive) {
                    delete(group)
                }
            } message: { _ in
                Text("Its budgets are removed. Its expenses are kept, without a group.")
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

    private func amountRow(_ key: BudgetKey) -> some View {
        HStack {
            Text("\(key.period.rawValue)ly")
            Spacer()
            TextField("No limit", value: binding(for: key), format: .currency(code: "NZD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: key)
        }
    }

    private func binding(for key: BudgetKey) -> Binding<Decimal?> {
        Binding(
            get: { amounts[key] ?? nil },
            set: { amounts[key] = $0 }
        )
    }

    private func existingBudget(for key: BudgetKey) -> Budget? {
        budgets.first { $0.period == key.period && $0.group?.persistentModelID == key.groupID }
    }

    private var allKeys: [BudgetKey] {
        var groupIDs: [PersistentIdentifier?] = visibleGroups.map(\.persistentModelID)
        if group == nil {
            groupIDs.insert(nil, at: 0)
        }
        return groupIDs.flatMap { id in BudgetPeriod.allCases.map { BudgetKey(groupID: id, period: $0) } }
    }

    /// Fills in amounts for keys not loaded yet (on open, and for groups added while open)
    /// without overwriting anything already typed.
    private func loadMissingAmounts() {
        for key in allKeys where !amounts.keys.contains(key) {
            amounts[key] = existingBudget(for: key)?.amount
        }
    }

    private func delete(_ group: ExpenseGroup) {
        for budget in budgets where budget.group?.persistentModelID == group.persistentModelID {
            DataStore.delete(budget, from: modelContext)
        }
        amounts = amounts.filter { $0.key.groupID != group.persistentModelID }
        // Clear the link now rather than waiting for the nullify on save: signed out, nothing
        // saves, and Reports would read the deleted group's name and crash.
        for expense in expenses where expense.group?.persistentModelID == group.persistentModelID {
            expense.group = nil
        }
        DataStore.delete(group, from: modelContext)
    }

    private func save() {
        for key in allKeys {
            let amount = amounts[key] ?? nil
            let existing = existingBudget(for: key)

            if let amount {
                if let existing {
                    existing.amount = amount
                } else {
                    let group = groups.first { $0.persistentModelID == key.groupID }
                    DataStore.insert(Budget(amount: amount, period: key.period, group: group), into: modelContext)
                }
            } else if let existing {
                DataStore.delete(existing, from: modelContext)
            }
        }

        DataStore.commit(modelContext)
        dismiss()
    }
}


#Preview {
    BudgetLimitsEditView()
        .modelContainer(PreviewSampleData.container)
}
