import SwiftUI
import SwiftData

struct ExpensesView: View {
    @State private var showingExpenseNew: Bool = false
    @Query private var expenses: [Expense]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(expenses) { expense in
                    NavigationLink {
//                        ExpensesView()
                    } label: {
                        Text(expense.title)
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
        }
        
    }
    
}


#Preview {
    ExpensesView()
        .modelContainer(PreviewSampleData.container)
}
