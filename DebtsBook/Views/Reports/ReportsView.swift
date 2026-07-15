import SwiftUI
import SwiftData

struct ReportsView: View {

    @State private var selectedRange: BudgetPeriod = .week
    @State private var showingBudgetEdit: Bool = false
    @State private var editingExpense: Expense?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var budgets: [Budget]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

    private var expensesInRange: [Expense] {
        let interval = selectedRange.dateInterval()
        return expenses.filter { $0.isPersonal && interval.contains($0.date) }
    }

    private var total: Decimal {
        expensesInRange.reduce(0) { $0 + $1.amount }
    }

    private var budgetForSelectedRange: Budget? {
        budgets.first { $0.period == selectedRange && $0.group == nil }
    }

    private var remaining: Decimal? {
        guard let budgetForSelectedRange else { return nil }
        return budgetForSelectedRange.amount - total
    }

    private var progress: Double {
        guard let budgetForSelectedRange, budgetForSelectedRange.amount > 0 else { return 0 }
        let fraction = total / budgetForSelectedRange.amount
        return min(Double(truncating: fraction as NSDecimalNumber), 1.0)
    }

    private var progressColor: Color {
        switch progress {
        case ..<0.8: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }

    private func groupSpent(_ group: ExpenseGroup) -> Decimal {
        let interval = selectedRange.dateInterval()
        return expenses
            .filter { $0.isPersonal && $0.group?.persistentModelID == group.persistentModelID && interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    private func groupBudget(_ group: ExpenseGroup) -> Budget? {
        budgets.first { $0.period == selectedRange && $0.group?.persistentModelID == group.persistentModelID }
    }

    private func groupProgress(_ group: ExpenseGroup) -> Double {
        guard let budget = groupBudget(group), budget.amount > 0 else { return 0 }
        let fraction = groupSpent(group) / budget.amount
        return min(Double(truncating: fraction as NSDecimalNumber), 1.0)
    }

    private func groupProgressColor(_ group: ExpenseGroup) -> Color {
        switch groupProgress(group) {
        case ..<0.8: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Range", selection: $selectedRange) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Text("Reports only track personal expenses (\"Just Me\") — expenses shared with friends aren't included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                budgetCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                if !expensesInRange.isEmpty {
                    Section("Personal Expenses") {
                        ForEach(expensesInRange) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .overlay {
                if expensesInRange.isEmpty && groups.isEmpty {
                    ContentUnavailableView(
                        "No Spending",
                        systemImage: "chart.bar",
                        description: Text("Personal expenses (\"Just Me\") for this \(selectedRange.rawValue.lowercased()) will show up here.")
                    )
                }
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $showingBudgetEdit) {
                BudgetLimitsEditView(period: selectedRange)
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseEditView(expense: expense)
            }
        }
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Spent This \(selectedRange.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(total, format: .currency(code: "NZD"))
                        .font(.title.bold())
                }
                Spacer()
                Button {
                    showingBudgetEdit = true
                } label: {
                    Image(systemName: budgetForSelectedRange == nil ? "target" : "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
            }

            if let budgetForSelectedRange, let remaining {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(progressColor)

                    HStack {
                        Text(remaining >= 0 ? "\(remaining, format: .currency(code: "NZD")) left" : "\(abs(remaining), format: .currency(code: "NZD")) over budget")
                            .foregroundColor(progressColor)
                            .fontWeight(.medium)
                        Spacer()
                        Text("of \(budgetForSelectedRange.amount, format: .currency(code: "NZD"))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    showingBudgetEdit = true
                } label: {
                    Text("Set a \(selectedRange.rawValue)ly Budget")
                }
                .font(.caption)
            }

            if !groups.isEmpty {
                Divider()

                ForEach(groups) { group in
                    groupBudgetLine(group)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func groupBudgetLine(_ group: ExpenseGroup) -> some View {
        let spent = groupSpent(group)
        let budget = groupBudget(group)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(spent, format: .currency(code: "NZD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if let budget {
                let remaining = budget.amount - spent
                ProgressView(value: groupProgress(group))
                    .tint(groupProgressColor(group))

                HStack {
                    Text(remaining >= 0 ? "\(remaining, format: .currency(code: "NZD")) left" : "\(abs(remaining), format: .currency(code: "NZD")) over budget")
                        .foregroundColor(groupProgressColor(group))
                        .fontWeight(.medium)
                    Spacer()
                    Text("of \(budget.amount, format: .currency(code: "NZD"))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } else {
                Text("No \(selectedRange.rawValue.lowercased())ly limit")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}


#Preview {
    ReportsView()
        .modelContainer(PreviewSampleData.container)
}
