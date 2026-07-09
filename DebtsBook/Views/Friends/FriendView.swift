import SwiftUI
import SwiftData

struct FriendView: View {
    
    @State private var showingFriendNew: Bool = false
    @Query private var friends: [Friend]

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        Text(friend.name)
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
        .modelContainer(for: Friend.self, inMemory: true)
}
