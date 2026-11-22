import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {

    @State private var selectedRange: BudgetPeriod = .week
    @State private var periodOffset: Int = 0
    @State private var selectedBarLabel: String?
    @State private var showingBudgetEdit: Bool = false
    @State private var editingExpense: Expense?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var budgets: [Budget]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

    private var selectedInterval: DateInterval {
        selectedRange.dateInterval(offset: periodOffset)
    }

    private var isCurrentPeriod: Bool {
        periodOffset == 0
    }

    private var expensesInRange: [Expense] {
        let interval = selectedInterval
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

    private var history: [PeriodSpending] {
        let count = selectedRange.historyLength
        var endOffset = 0
        if periodOffset <= -count {
            endOffset = periodOffset
        }
        return personalSpendingHistory(expenses: expenses, period: selectedRange, count: count, endOffset: endOffset)
    }

    private func barLabel(_ spending: PeriodSpending) -> String {
        switch selectedRange {
        case .week: return spending.interval.start.formatted(.dateTime.day().month(.abbreviated))
        case .month: return spending.interval.start.formatted(.dateTime.month(.abbreviated))
        case .year: return spending.interval.start.formatted(.dateTime.year(.twoDigits))
        }
    }

    private func groupSpent(_ group: ExpenseGroup) -> Decimal {
        let interval = selectedInterval
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
                .onChange(of: selectedRange) {
                    periodOffset = 0
                }

                periodNavigator
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

                if history.allSatisfy({ $0.total == 0 }) {
                    ContentUnavailableView(
                        "No Spending",
                        systemImage: "chart.bar",
                        description: Text("Personal expenses (\"Just Me\") for \(selectedRange.label(for: selectedInterval)) will show up here.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    historyChart
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

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
                    Text(isCurrentPeriod ? "Total Spent This \(selectedRange.rawValue)" : "Total Spent")
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
                        SyncIcon(item: budgetForSelectedRange)
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

    private var relativePeriodTitle: String {
        let unit = selectedRange.rawValue
        switch periodOffset {
        case 0: return "This \(unit)"
        case -1: return "Last \(unit)"
        default: return "\(-periodOffset) \(unit)s Ago"
        }
    }

    private var periodNavigator: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    periodOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Previous \(selectedRange.rawValue)")

                Spacer()

                VStack(spacing: 2) {
                    Text(relativePeriodTitle)
                        .font(.headline)
                    Text(selectedRange.label(for: selectedInterval))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.numericText())

                Spacer()

                Button {
                    periodOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .disabled(isCurrentPeriod)
                .accessibilityLabel("Next \(selectedRange.rawValue)")
            }
            .buttonStyle(.borderless)
            .tint(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())

            if !isCurrentPeriod {
                Button {
                    periodOffset = 0
                } label: {
                    Label("Back to This \(selectedRange.rawValue)", systemImage: "arrow.uturn.forward")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        }
        .animation(.default, value: periodOffset)
    }

    /// Group names with spending in the visible periods, alphabetical, with "No Group" last.
    private func chartSeriesNames(_ history: [PeriodSpending]) -> [String] {
        let names = Set(history.flatMap { $0.byGroup.keys })
        var sorted = names.subtracting([PeriodSpending.noGroupName]).sorted()
        if names.contains(PeriodSpending.noGroupName) {
            sorted.append(PeriodSpending.noGroupName)
        }
        return sorted
    }

    private func chartSeriesColors(_ history: [PeriodSpending]) -> [Color] {
        let palette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .yellow, .indigo, .red, .mint]
        return chartSeriesNames(history).enumerated().map { index, name in
            if name == PeriodSpending.noGroupName {
                return .gray
            }
            return palette[index % palette.count]
        }
    }

    @ViewBuilder
    private func xAxisLabel(for label: String, in history: [PeriodSpending]) -> some View {
        if let index = history.firstIndex(where: { barLabel($0) == label }) {
            let spending = history[index]
            let isSelected = spending.offset == periodOffset
            Group {
                if selectedRange == .week {
                    let start = spending.interval.start
                    let monthChanged = index == 0 || !Calendar.current.isDate(history[index - 1].interval.start, equalTo: start, toGranularity: .month)
                    VStack(spacing: 0) {
                        Text(start.formatted(.dateTime.day()))
                        Text(monthChanged ? start.formatted(.dateTime.month(.abbreviated)) : " ")
                    }
                } else {
                    Text(label)
                }
            }
            .fontWeight(isSelected ? .bold : .regular)
            .foregroundStyle(isSelected ? .primary : .secondary)
        } else {
            Text(label)
        }
    }

    private var historyChart: some View {
        let history = history
        let budgetAmount = budgetForSelectedRange.map { Double(truncating: $0.amount as NSDecimalNumber) }

        return VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart {
                if let selected = history.first(where: { $0.offset == periodOffset }) {
                    RectangleMark(x: .value("Period", barLabel(selected)))
                        .foregroundStyle(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                ForEach(history) { spending in
                    ForEach(chartSeriesNames(history), id: \.self) { name in
                        if let amount = spending.byGroup[name] {
                            BarMark(
                                x: .value("Period", barLabel(spending)),
                                y: .value("Spent", Double(truncating: amount as NSDecimalNumber))
                            )
                            .foregroundStyle(by: .value("Group", name))
                            .opacity(spending.offset == periodOffset ? 1 : 0.3)
                        }
                    }
                }

                if let budgetAmount {
                    RuleMark(y: .value("Budget", budgetAmount))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: history.map(barLabel))
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            xAxisLabel(for: label, in: history)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: chartSeriesNames(history), range: chartSeriesColors(history))
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXSelection(value: $selectedBarLabel)
            .onChange(of: selectedBarLabel) {
                guard let selectedBarLabel,
                      let tapped = history.first(where: { barLabel($0) == selectedBarLabel }) else { return }
                periodOffset = tapped.offset
            }
            .frame(height: 200)
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
                    SyncIcon(item: budget)
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
