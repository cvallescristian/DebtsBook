import SwiftUI
import SwiftData

struct FriendView: View {
    
    @State private var showingFriendNew: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    FriendDetailView()
                } label: {
                    HStack {
                        Text("Cristian")
                        Spacer()
                        Text("$10.00 NZD")
                            .foregroundColor(.green)
                    }
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
}
