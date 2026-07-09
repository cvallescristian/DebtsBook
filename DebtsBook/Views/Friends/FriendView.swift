import SwiftUI
import SwiftData

struct FriendView: View {
    
    @State private var showingFriendNew: Bool = false
    @Query private var friends: [Friend]
    @Query private var expenses: [Expense]

    private func balance(for friend: Friend) -> Decimal {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .netBalance
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        HStack {
                            Text(friend.name)
                            Spacer()
                            if balance(for: friend) == 0 {
                                Label("Settled up", systemImage: "hand.thumbsup.fill")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(balance(for: friend), format: .currency(code: "NZD").sign(strategy: .always()))
                                    .foregroundColor(balance(for: friend) > 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .overlay {
                if friends.isEmpty {
                    ContentUnavailableView("No Friends", systemImage: "person.2", description: Text("Tap + to add your first friend."))
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                Button {
                    showingFriendNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingFriendNew){
                FriendNewView()
            }
        }
    }
}


#Preview {
    FriendView()
        .modelContainer(PreviewSampleData.container)
}
