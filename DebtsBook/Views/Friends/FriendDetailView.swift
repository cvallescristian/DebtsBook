import SwiftUI
import SwiftData

struct FriendDetailView: View {

    let friend: Friend
    @State private var showingFriendEdit: Bool = false
    @Environment(\.dismiss) private var dismiss

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
        .navigationTitle(friend.name)
        .toolbar {
            Button {
                showingFriendEdit = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
        .sheet(isPresented: $showingFriendEdit){
            FriendEditView(friend: friend, onDelete: { dismiss() })
        }
    }
}


#Preview {
    NavigationStack {
        FriendDetailView(friend: PreviewSampleData.friend)
    }
    .modelContainer(PreviewSampleData.container)
}
