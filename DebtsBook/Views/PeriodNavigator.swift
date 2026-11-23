import SwiftUI

/// The Reports period bar: ‹ › arrows, a title that opens the calendar picker, and a ↩
/// button back to now once you've moved away from it.
struct PeriodNavigator: View {

    let range: BudgetPeriod
    @Binding var offset: Int
    /// Dates of the expenses the screen covers: the oldest one stops the ‹ arrow and the
    /// calendar, and the calendar marks periods that have any.
    let dates: [Date]

    @State private var showingPicker = false

    private var interval: DateInterval {
        range.dateInterval(offset: offset)
    }

    private var isCurrentPeriod: Bool {
        offset == 0
    }

    private var canGoBack: Bool {
        guard let oldest = dates.min() else { return false }
        return oldest < interval.start
    }

    private var relativeTitle: String {
        let unit = range.rawValue
        switch offset {
        case 0: return "This \(unit)"
        case -1: return "Last \(unit)"
        default: return "\(-offset) \(unit)s Ago"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                arrow(systemImage: "chevron.left", label: "Previous \(range.rawValue)") {
                    offset -= 1
                }
                .disabled(!canGoBack)

                Button {
                    showingPicker = true
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(relativeTitle)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(range.label(for: interval))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentTransition(.numericText())
                .accessibilityHint("Choose a \(range.rawValue.lowercased())")

                if !isCurrentPeriod {
                    arrow(systemImage: "arrow.uturn.forward", label: "Back to This \(range.rawValue)") {
                        offset = 0
                    }
                }

                arrow(systemImage: "chevron.right", label: "Next \(range.rawValue)") {
                    offset += 1
                }
                .disabled(isCurrentPeriod)
            }
            .padding(4)
            .background(.thinMaterial, in: Capsule())
        }
        .animation(.default, value: offset)
        .sheet(isPresented: $showingPicker) {
            ReportsPeriodPicker(range: range, selected: interval, spendingDates: dates) { chosenRange, date in
                offset = chosenRange.offset(of: date)
            }
        }
    }

    private func arrow(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
