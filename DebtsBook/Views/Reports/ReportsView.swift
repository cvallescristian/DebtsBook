import SwiftUI
import SwiftData

private enum ReportRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var dateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, end: now)
    }
}

struct ReportsView: View {

    @State private var selectedRange: ReportRange = .week
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    private var expensesInRange: [Expense] {
        let interval = selectedRange.dateInterval
        return expenses.filter { $0.paidByMe && interval.contains($0.date) }
    }

    private var total: Decimal {
        expensesInRange.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Range", selection: $selectedRange) {
                    ForEach(ReportRange.allCases, id: \.self) { range in
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
        }
    }
}


#Preview {
    ReportsView()
        .modelContainer(PreviewSampleData.container)
}
