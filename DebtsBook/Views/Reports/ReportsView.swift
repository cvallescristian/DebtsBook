import SwiftUI
import SwiftData

struct ReportsView: View {

    @State private var selectedRange: BudgetPeriod = .week
    @State private var showingBudgetEdit: Bool = false
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var budgets: [Budget]

    private var expensesInRange: [Expense] {
        let interval = selectedRange.dateInterval()
        return expenses.filter { $0.paidByMe && interval.contains($0.date) }
    }

    private var total: Decimal {
        expensesInRange.reduce(0) { $0 + $1.amount }
    }

    private var budgetForSelectedRange: Budget? {
        budgets.first { $0.period == selectedRange }
    }

    private var remaining: Decimal? {
        guard let budgetForSelectedRange else { return nil }
        return budgetForSelectedRange.amount - total
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

                VStack(spacing: 4) {
                    Text("Total Spent This \(selectedRange.rawValue)")
                        .foregroundStyle(.secondary)
                    Text(total, format: .currency(code: "NZD"))
                        .font(.largeTitle.bold())
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Button {
                    showingBudgetEdit = true
                } label: {
                    if let budgetForSelectedRange, let remaining {
                        VStack(spacing: 4) {
                            Text(remaining >= 0 ? "Remaining Budget" : "Over Budget")
                                .foregroundStyle(.secondary)
                            Text(abs(remaining), format: .currency(code: "NZD"))
                                .font(.title.bold())
                                .foregroundColor(remaining >= 0 ? .green : .red)
                            Text("of \(budgetForSelectedRange.amount, format: .currency(code: "NZD")) budget")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Set a \(selectedRange.rawValue)ly Budget", systemImage: "target")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !expensesInRange.isEmpty {
                    Section("Expenses") {
                        ForEach(expensesInRange) { expense in
                            ExpenseRow(expense: expense)
                        }
                    }
                }
            }
            .overlay {
                if expensesInRange.isEmpty {
                    ContentUnavailableView(
                        "No Spending",
                        systemImage: "chart.bar",
                        description: Text("Expenses you paid for this \(selectedRange.rawValue.lowercased()) will show up here.")
                    )
                }
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $showingBudgetEdit) {
                BudgetEditView(period: selectedRange, existingBudget: budgetForSelectedRange)
            }
        }
    }
}


#Preview {
    ReportsView()
        .modelContainer(PreviewSampleData.container)
}
