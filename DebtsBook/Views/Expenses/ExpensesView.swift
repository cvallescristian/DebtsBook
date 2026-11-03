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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(pending)
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    loggingPending = pending
                                } label: {
                                    Label("Log", systemImage: "square.and.pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        Label("Pending · \(pendingExpenses.count)", systemImage: "clock")
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
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(.orange.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pending.merchant)
                    Spacer()
                    Text(pending.amount, format: .currency(code: "NZD"))
                }
                HStack {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Pending")
                        .foregroundColor(.orange)
                }
                .font(.caption)
            }
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
