import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {

    @State private var selectedRange: BudgetPeriod = .week
    @State private var periodOffset: Int = 0
    @State private var selectedBarLabel: String?
    @State private var showingBudgetEdit: Bool = false
    @State private var editingExpense: Expense?
    @State private var groupFilter: String?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var budgets: [Budget]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

    private var selectedInterval: DateInterval {
        selectedRange.dateInterval(offset: periodOffset)
    }

    private var isCurrentPeriod: Bool {
        periodOffset == 0
    }

    /// False once the selected period holds the oldest personal expense (or there are none).
    private var canGoBack: Bool {
        guard let oldest = expenses.last(where: { $0.isPersonal }) else { return false }
        return oldest.date < selectedInterval.start
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

    private static let previewCount = 5

    private var filteredExpenses: [Expense] {
        guard let groupFilter else { return expensesInRange }
        return expensesInRange.filter { ($0.group?.name ?? PeriodSpending.noGroupName) == groupFilter }
    }

    /// Groups with spending or a budget this period: budgeted ones first, then most spent first.
    /// Unbudgeted groups with no spending are left out.
    private var visibleGroups: [ExpenseGroup] {
        groups
            .filter { groupSpent($0) > 0 || groupBudget($0) != nil }
            .sorted { lhs, rhs in
                let lhsBudgeted = groupBudget(lhs) != nil
                let rhsBudgeted = groupBudget(rhs) != nil
                if lhsBudgeted != rhsBudgeted {
                    return lhsBudgeted
                }
                return groupSpent(lhs) > groupSpent(rhs)
            }
    }

    private var ungroupedSpent: Decimal {
        expensesInRange.filter { $0.group == nil }.reduce(0) { $0 + $1.amount }
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
                    groupFilter = nil
                }
                .onChange(of: periodOffset) {
                    groupFilter = nil
                }

                periodNavigator
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                summaryCard
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
                    if !visibleGroups.isEmpty || ungroupedSpent > 0 {
                        Section("By Group") {
                            ForEach(visibleGroups) { group in
                                groupRow(group: group, name: group.name, spent: groupSpent(group), budget: groupBudget(group))
                            }
                            if ungroupedSpent > 0 {
                                groupRow(group: nil, name: PeriodSpending.noGroupName, spent: ungroupedSpent, budget: nil)
                            }
                        }
                    }

                    expensesSection
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingBudgetEdit = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Budget")
                }
            }
            .sheet(isPresented: $showingBudgetEdit) {
                BudgetLimitsEditView()
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseEditView(expense: expense)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCurrentPeriod ? "Total Spent This \(selectedRange.rawValue)" : "Total Spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(total, format: .currency(code: "NZD"))
                .font(.largeTitle.bold())
                .contentTransition(.numericText())

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
                    Label("Set \(selectedRange.rawValue)ly Budget", systemImage: "target")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if !history.allSatisfy({ $0.total == 0 }) {
                historyChart
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.default, value: periodOffset)
    }

    private var expensesSection: some View {
        Section {
            if filteredExpenses.isEmpty {
                Text("No expenses this \(selectedRange.rawValue.lowercased()).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredExpenses.prefix(Self.previewCount)) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                    .tint(.primary)
                }
                if filteredExpenses.count > Self.previewCount {
                    NavigationLink {
                        ReportsExpenseListView(
                            title: groupFilter ?? selectedRange.label(for: selectedInterval),
                            expenses: filteredExpenses
                        )
                    } label: {
                        Text("See All (\(filteredExpenses.count))")
                            .foregroundStyle(.tint)
                    }
                }
            }
        } header: {
            HStack {
                Text(groupFilter.map { "\($0) Expenses" } ?? "Expenses")
                Spacer()
                if groupFilter != nil {
                    Button("Show All") {
                        groupFilter = nil
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        } footer: {
            Text("Reports only track personal expenses (\"Just Me\"). Expenses shared with friends aren't included.")
        }
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
            HStack(spacing: 0) {
                periodArrow(systemImage: "chevron.left", label: "Previous \(selectedRange.rawValue)") {
                    periodOffset -= 1
                }
                .disabled(!canGoBack)

                VStack(spacing: 2) {
                    Text(relativePeriodTitle)
                        .font(.headline)
                    Text(selectedRange.label(for: selectedInterval))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())

                periodArrow(systemImage: "chevron.right", label: "Next \(selectedRange.rawValue)") {
                    periodOffset += 1
                }
                .disabled(isCurrentPeriod)
            }
            .padding(4)
            .background(.thinMaterial, in: Capsule())

            if !isCurrentPeriod {
                Button {
                    periodOffset = 0
                } label: {
                    Label("Back to This \(selectedRange.rawValue)", systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .animation(.default, value: periodOffset)
    }

    private func periodArrow(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
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
        chartSeriesNames(history).map(seriesColor)
    }

    private func seriesColor(_ name: String) -> Color {
        groups.first { $0.name == name }?.displayColor ?? .gray
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
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedBarLabel)
            .onChange(of: selectedBarLabel) {
                guard let selectedBarLabel,
                      let tapped = history.first(where: { barLabel($0) == selectedBarLabel }) else { return }
                periodOffset = tapped.offset
            }
            .frame(height: 180)
        }
    }

    @ViewBuilder
    private func groupRow(group: ExpenseGroup?, name: String, spent: Decimal, budget: Budget?) -> some View {
        let isFiltered = groupFilter == name

        VStack(alignment: .leading, spacing: 6) {
            Button {
                if isFiltered {
                    groupFilter = nil
                } else {
                    groupFilter = name
                }
            } label: {
                HStack(spacing: 12) {
                    if let group {
                        GroupIcon(group: group)
                    } else {
                        GroupIcon(name: name, iconName: "tray.fill", color: .gray)
                    }
                    Text(name)
                        .fontWeight(.medium)
                    Spacer()
                    Text(spent, format: .currency(code: "NZD"))
                        .fontWeight(.semibold)
                    if isFiltered {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.primary)

            if let budget {
                let remaining = budget.amount - spent
                let fraction = budget.amount > 0 ? Double(truncating: (spent / budget.amount) as NSDecimalNumber) : 0
                let color = budgetColor(fraction)
                ProgressView(value: min(fraction, 1))
                    .tint(color)

                HStack {
                    Text(remaining >= 0 ? "\(remaining, format: .currency(code: "NZD")) left" : "\(abs(remaining), format: .currency(code: "NZD")) over budget")
                        .foregroundColor(color)
                        .fontWeight(.medium)
                    Spacer()
                    Text("of \(budget.amount, format: .currency(code: "NZD"))")
                        .foregroundStyle(.secondary)
                    SyncIcon(item: budget)
                }
                .font(.caption)
            } else if group != nil {
                HStack {
                    Text("No \(selectedRange.rawValue.lowercased())ly limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set Limit") {
                        showingBudgetEdit = true
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
        }
    }

    private func budgetColor(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.8: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }
}

private struct ReportsExpenseListView: View {
    let title: String
    let expenses: [Expense]
    @State private var editingExpense: Expense?

    var body: some View {
        List(expenses) { expense in
            Button {
                editingExpense = expense
            } label: {
                ExpenseRow(expense: expense)
            }
            .tint(.primary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }
}


#Preview {
    ReportsView()
        .modelContainer(PreviewSampleData.container)
}
