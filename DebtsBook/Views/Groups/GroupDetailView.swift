import SwiftUI
import SwiftData

struct GroupDetailView: View {

    let group: ExpenseGroup

    @Query private var expenses: [Expense]
    @Query private var budgets: [Budget]
    @State private var showingEdit: Bool = false
    @State private var editingBudgetPeriod: BudgetPeriod?
    @State private var editingExpense: Expense?
    @Environment(\.dismiss) private var dismiss

    private var groupExpenses: [Expense] {
        expenses
            .filter { $0.group?.persistentModelID == group.persistentModelID }
            .sorted { $0.date > $1.date }
    }

    private var groupBudgets: [Budget] {
        budgets.filter { $0.group?.persistentModelID == group.persistentModelID }
    }

    private func budget(for period: BudgetPeriod) -> Budget? {
        groupBudgets.first { $0.period == period }
    }

    private func spent(for period: BudgetPeriod) -> Decimal {
        let interval = period.dateInterval()
        return groupExpenses
            .filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    private func progress(for period: BudgetPeriod) -> Double {
        guard let budget = budget(for: period), budget.amount > 0 else { return 0 }
        let fraction = spent(for: period) / budget.amount
        return min(Double(truncating: fraction as NSDecimalNumber), 1.0)
    }

    private func progressColor(for period: BudgetPeriod) -> Color {
        switch progress(for: period) {
        case ..<0.8: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }

    var body: some View {
        List {
            Section("Budgets") {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    budgetCard(for: period)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if !groupExpenses.isEmpty {
                Section("Expenses") {
                    ForEach(groupExpenses) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(expense.title)
                                    Text(expense.date, format: .dateTime.day().month())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(expense.amount, format: .currency(code: "NZD"))
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .overlay {
            if groupExpenses.isEmpty && groupBudgets.isEmpty {
                ContentUnavailableView("No Expenses", systemImage: "tray", description: Text("Add personal expenses to this group."))
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            Button {
                showingEdit = true
            } label: {
                Text("Edit")
            }
        }
        .sheet(isPresented: $showingEdit) {
            GroupEditView(group: group) {
                dismiss()
            }
        }
        .sheet(item: $editingBudgetPeriod) { period in
            BudgetEditView(period: period, existingBudget: budget(for: period), group: group)
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }

    @ViewBuilder
    private func budgetCard(for period: BudgetPeriod) -> some View {
        let periodBudget = budget(for: period)
        let periodSpent = spent(for: period)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(period.rawValue)ly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(periodSpent, format: .currency(code: "NZD"))
                        .font(.title3.bold())
                }
                Spacer()
                Button {
                    editingBudgetPeriod = period
                } label: {
                    Image(systemName: periodBudget == nil ? "target" : "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
            }

            if let periodBudget {
                let remaining = periodBudget.amount - periodSpent
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress(for: period))
                        .tint(progressColor(for: period))

                    HStack {
                        Text(remaining >= 0 ? "\(remaining, format: .currency(code: "NZD")) left" : "\(abs(remaining), format: .currency(code: "NZD")) over budget")
                            .foregroundColor(progressColor(for: period))
                            .fontWeight(.medium)
                        Spacer()
                        Text("of \(periodBudget.amount, format: .currency(code: "NZD"))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    editingBudgetPeriod = period
                } label: {
                    Text("Set a \(period.rawValue.lowercased())ly limit")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension BudgetPeriod: @retroactive Identifiable {
    public var id: String { rawValue }
}


#Preview {
    NavigationStack {
        GroupDetailView(group: ExpenseGroup(name: "Food"))
    }
    .modelContainer(PreviewSampleData.container)
}
