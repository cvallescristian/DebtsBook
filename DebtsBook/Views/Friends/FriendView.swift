import SwiftUI
import SwiftData

struct FriendView: View {

    @State private var showingFriendNew: Bool = false
    @State private var showingRedeemInvite: Bool = false
    @State private var showingSignInRequired: Bool = false
    @State private var expandedFriend: Friend?
    var authService = AuthService.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]
    @Query private var expenses: [Expense]

    private func balance(for friend: Friend) -> Decimal {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .netBalance
    }

    private var overallBalance: Decimal {
        expenses.netBalance
    }

    var body: some View {
        NavigationStack {
            friendsList
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if authService.isSignedIn {
                            showingRedeemInvite = true
                        } else {
                            showingSignInRequired = true
                        }
                    } label: {
                        Image(systemName: "link.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingFriendNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFriendNew) {
                FriendNewView()
            }
            .sheet(isPresented: $showingRedeemInvite) {
                RedeemInviteView()
            }
            .sheet(isPresented: $showingSignInRequired) {
                SignInRequiredView()
            }
        }
        .expandedAvatar($expandedFriend)
    }

    private var summary: some View {
        HStack(spacing: 4) {
            if overallBalance > 0 {
                Text("Overall, you are owed")
                Text(overallBalance, format: .currency(code: "NZD"))
                    .foregroundColor(.green)
                    .bold()
            } else if overallBalance < 0 {
                Text("Overall, you owe")
                Text(-overallBalance, format: .currency(code: "NZD"))
                    .foregroundColor(.red)
                    .bold()
            } else {
                Text("All settled up")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .textCase(nil)
    }

    private var friendsList: some View {
        List {
            Section {
                ForEach(Array(friends.enumerated()), id: \.element.persistentModelID) { index, friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        VStack(spacing: 0) {
                            // The tap target sits over the row's avatar rather than inside FriendRow,
                            // so rows don't redraw (and read a just-deleted friend) on every list update.
                            FriendRow(friend: friend, balance: balance(for: friend))
                                .overlay(alignment: .leading) {
                                    Color.clear
                                        .frame(width: 44, height: 44)
                                        .contentShape(Circle())
                                        .highPriorityGesture(TapGesture().onEnded { expandedFriend = friend })
                                        .accessibilityAddTraits(.isButton)
                                        .accessibilityLabel("Show \(friend.name)'s photo")
                                }
                                .padding(.vertical, 8)
                            if index < friends.count - 1 {
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 0.5)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            } header: {
                summary
            }
        }
        .overlay {
            if friends.isEmpty {
                ContentUnavailableView("No Friends", systemImage: "person.2", description: Text("Tap + to add your first friend."))
            }
        }
        .refreshable {
            await SyncCoordinator.syncAll(into: modelContext)
        }
    }
}


#Preview {
    FriendView()
        .modelContainer(PreviewSampleData.container)
}
