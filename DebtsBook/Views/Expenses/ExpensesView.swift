import SwiftUI
import SwiftData

struct ExpensesView: View {
    @State private var showingExpenseNew: Bool = false
    @State private var editingExpense: Expense?
    @Query(sort: \Expense.createdAt, order: .reverse) private var expenses: [Expense]

    private var balance: Decimal {
        expenses.netBalance
    }

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    if balance > 0 {
                        Text("Overall, you are owed")
                        Text(balance, format: .currency(code: "NZD"))
                            .foregroundColor(.green)
                            .bold()
                    } else if balance < 0 {
                        Text("Overall, you owe")
                        Text(-balance, format: .currency(code: "NZD"))
                            .foregroundColor(.red)
                            .bold()
                    } else {
                        Text("All settled up")
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    ForEach(expenses) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .tint(.primary)
                        .settleSwipeAction(for: expense)
                    }
                }
            } .overlay {
                if expenses.isEmpty {
                    ContentUnavailableView("No Expenses", systemImage: "dollarsign.circle", description: Text("Expenses will show up here."))
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                Button {
                    showingExpenseNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
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
