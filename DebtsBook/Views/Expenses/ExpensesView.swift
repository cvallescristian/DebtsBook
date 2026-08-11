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
    @State private var selectedFilter: ExpenseFilter = .all
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

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
                if filteredExpenses.isEmpty {
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
        }
        
    }
    
}


#Preview {
    ExpensesView()
        .modelContainer(PreviewSampleData.container)
}
