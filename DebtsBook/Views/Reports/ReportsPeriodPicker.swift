import SwiftUI

/// Calendar for jumping straight to a week, month or year in Reports.
/// Only periods between the oldest personal expense and now can be picked.
struct ReportsPeriodPicker: View {

    /// The range of `selected`.
    let selectedRange: BudgetPeriod
    let selected: DateInterval
    /// Dates of personal expenses, used to mark periods and days that have spending.
    let spendingDates: [Date]
    /// Shows a Week / Month / Year switch at the top so the range can be changed here too.
    let allowsRangeChange: Bool
    let onSelect: (BudgetPeriod, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The range being browsed; only differs from `selectedRange` when `allowsRangeChange`.
    @State private var range: BudgetPeriod
    /// The month (week view) or year (month view) being shown.
    @State private var page: Date

    private let calendar = Calendar.current

    init(range: BudgetPeriod, selected: DateInterval, spendingDates: [Date], allowsRangeChange: Bool = false, onSelect: @escaping (BudgetPeriod, Date) -> Void) {
        self.selectedRange = range
        self.selected = selected
        self.spendingDates = spendingDates
        self.allowsRangeChange = allowsRangeChange
        self.onSelect = onSelect
        _range = State(initialValue: range)
        _page = State(initialValue: selected.start)
    }

    private func isSelected(_ interval: DateInterval) -> Bool {
        range == selectedRange && interval.start == selected.start
    }

    private var earliest: Date {
        spendingDates.min() ?? Date()
    }

    private func isAvailable(_ interval: DateInterval) -> Bool {
        let first = range.dateInterval(containing: earliest).start
        let last = range.dateInterval(containing: Date()).start
        return interval.start >= first && interval.start <= last
    }

    private func hasSpending(_ interval: DateInterval) -> Bool {
        spendingDates.contains { interval.contains($0) && $0 < interval.end }
    }

    private var title: String {
        switch range {
        case .week: return "Choose Week"
        case .month: return "Choose Month"
        case .year: return "Choose Year"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if allowsRangeChange {
                        Picker("Range", selection: $range) {
                            ForEach(BudgetPeriod.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    switch range {
                    case .week: weekCalendar
                    case .month: monthGrid
                    case .year: yearGrid
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func choose(_ interval: DateInterval) {
        onSelect(range, interval.start)
        dismiss()
    }

    // MARK: Paging header

    private func pageHeader(_ label: String, component: Calendar.Component) -> some View {
        let current = calendar.dateInterval(of: component, for: page)?.start ?? page
        let first = calendar.dateInterval(of: component, for: earliest)?.start ?? earliest
        let last = calendar.dateInterval(of: component, for: Date())?.start ?? Date()

        return HStack {
            pageButton("chevron.left", label: "Previous") {
                page = calendar.date(byAdding: component, value: -1, to: page) ?? page
            }
            .disabled(current <= first)

            Spacer()
            Text(label)
                .font(.headline)
            Spacer()

            pageButton("chevron.right", label: "Next") {
                page = calendar.date(byAdding: component, value: 1, to: page) ?? page
            }
            .disabled(current >= last)
        }
    }

    private func pageButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    // MARK: Week

    private var weeksOfPage: [DateInterval] {
        guard let month = calendar.dateInterval(of: .month, for: page) else { return [] }
        var weeks: [DateInterval] = []
        var weekStart = BudgetPeriod.week.dateInterval(containing: month.start).start
        while weekStart < month.end {
            let week = BudgetPeriod.week.dateInterval(containing: weekStart)
            weeks.append(week)
            weekStart = week.end
        }
        return weeks
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var weekCalendar: some View {
        VStack(spacing: 6) {
            pageHeader(page.formatted(.dateTime.month(.wide).year()), component: .month)

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weeksOfPage, id: \.start) { week in
                weekRow(week)
            }
        }
    }

    private func weekRow(_ week: DateInterval) -> some View {
        let isSelected = isSelected(week)
        let available = isAvailable(week)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }

        return Button {
            choose(week)
        } label: {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let inPage = calendar.isDate(day, equalTo: page, toGranularity: .month)
                    let dayInterval = calendar.dateInterval(of: .day, for: day)
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.day()))
                            .font(.body)
                            .opacity(inPage ? 1 : 0.4)
                        Circle()
                            .frame(width: 5, height: 5)
                            .opacity(dayInterval.map(hasSpending) == true ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .periodCellStyle(isSelected: isSelected, isCurrent: week.contains(Date()), shape: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.35)
        .accessibilityLabel(BudgetPeriod.week.label(for: week))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Month

    private var monthGrid: some View {
        let year = calendar.dateInterval(of: .year, for: page)?.start ?? page
        let months = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: year) }

        return VStack(spacing: 12) {
            pageHeader(page.formatted(.dateTime.year()), component: .year)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(months, id: \.self) { month in
                    periodCell(BudgetPeriod.month.dateInterval(containing: month), label: month.formatted(.dateTime.month(.abbreviated)))
                }
            }
        }
    }

    // MARK: Year

    private var yearGrid: some View {
        let firstYear = calendar.component(.year, from: earliest)
        let lastYear = calendar.component(.year, from: Date())
        let years = (firstYear...max(firstYear, lastYear)).compactMap { calendar.date(from: DateComponents(year: $0)) }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(years, id: \.self) { year in
                periodCell(BudgetPeriod.year.dateInterval(containing: year), label: year.formatted(.dateTime.year()))
            }
        }
    }

    private func periodCell(_ interval: DateInterval, label: String) -> some View {
        let isSelected = isSelected(interval)
        let available = isAvailable(interval)

        return Button {
            choose(interval)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.body.weight(.medium))
                Circle()
                    .frame(width: 5, height: 5)
                    .opacity(hasSpending(interval) ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .periodCellStyle(isSelected: isSelected, isCurrent: interval.contains(Date()), shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.35)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    /// Filled with the accent colour when selected; outlined when it's the period containing today.
    func periodCellStyle<S: InsettableShape>(isSelected: Bool, isCurrent: Bool, shape: S) -> some View {
        self
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                if isSelected {
                    shape.fill(Color.accentColor)
                } else {
                    shape.fill(Color(.secondarySystemFill))
                }
            }
            .overlay {
                if isCurrent && !isSelected {
                    shape.strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .contentShape(shape)
    }
}
