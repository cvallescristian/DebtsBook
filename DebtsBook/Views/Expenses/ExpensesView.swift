import SwiftUI
import SwiftData

private enum ExpenseFilter: String, CaseIterable {
    case all = "All"
    case unpaid = "Unpaid"
    case paid = "Paid"
    case personal = "Personal"
}

struct ExpensesView: View {
    @State private var showingExpenseNew: Bool = false
    @State private var editingExpense: Expense?
    @State private var loggingPending: PendingExpense?
    @State private var selectedFilter: ExpenseFilter = .all
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \PendingExpense.date, order: .reverse) private var pendingExpenses: [PendingExpense]

    private var filteredExpenses: [Expense] {
        switch selectedFilter {
        case .all: return expenses
        case .unpaid: return expenses.filter { !$0.isPersonal && !$0.isSettled }
        case .paid: return expenses.filter { !$0.isPersonal && $0.isSettled }
        case .personal: return expenses.filter { $0.isPersonal }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ExpenseFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !pendingExpenses.isEmpty {
                    Section {
                        ForEach(pendingExpenses) { pending in
                            Button {
                                loggingPending = pending
                            } label: {
                                PendingExpenseRow(pending: pending)
                            }
                            .tint(.primary)
                            .accessibilityIdentifier("pendingExpenseRow")
                            .swipeActions {
                                Button("Dismiss", role: .destructive) {
                                    modelContext.delete(pending)
                                }
                            }
                        }
                    } header: {
                        Text("Pending from Apple Pay")
                    } footer: {
                        Text("Tap to log as an expense, or swipe to dismiss.")
                    }
                }

                Section {
                    ForEach(filteredExpenses) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .tint(.primary)
                        .settleSwipeAction(for: expense, in: modelContext)
                    }
                }
            } .overlay {
                if filteredExpenses.isEmpty && pendingExpenses.isEmpty {
                    ContentUnavailableView("No Expenses", systemImage: "dollarsign.circle", description: Text("Expenses will show up here."))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingExpenseNew = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .padding()
            }
            .navigationTitle("Expenses")
            .sheet(isPresented: $showingExpenseNew){
                ExpenseNewView()
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseEditView(expense: expense)
            }
            .sheet(item: $loggingPending) { pending in
                ExpenseNewView(pending: pending)
            }
        }

    }

}

private struct PendingExpenseRow: View {
    let pending: PendingExpense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pending.merchant)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(pending.amount, format: .currency(code: "NZD"))
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let date = pending.date.formatted(date: .abbreviated, time: .shortened)
        guard let card = pending.cardName, !card.isEmpty else { return date }
        return "\(card) · \(date)"
    }
}


#Preview {
    ExpensesView()
        .modelContainer(PreviewSampleData.container)
}
