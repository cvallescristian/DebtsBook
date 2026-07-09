import SwiftUI
import SwiftData

struct FriendDetailView: View {
    
    var body: some View {
        List {
            HStack {
                Text("Overall, you are owned")
                    .font(.title2)
                Text("$10.00")
                    .foregroundColor(.green)
                    .font(Font.title2.bold())
            }
            .listRowBackground(Color.clear)

            Section("Expenses") {
                ForEach(0..<20) {
                    Text("Expense \($0)")
                }
            }
        }
        .navigationTitle("Cristian")
        .toolbar {
            Button {
//                    showingAddExpense = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
    }
}


#Preview {
    NavigationStack {
        FriendDetailView()
    }
}
