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
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

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
