import SwiftUI
import SwiftData

enum FriendTab: String, CaseIterable {
    case friends = "Friends"
    case groups = "Groups"
}

struct FriendView: View {

    @State private var selectedTab: FriendTab = .friends
    @State private var showingFriendNew: Bool = false
    @State private var showingGroupNew: Bool = false
    @State private var showingRedeemInvite: Bool = false
    @State private var showingSignInRequired: Bool = false
    var authService = AuthService.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]
    @Query private var expenses: [Expense]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

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
            VStack(spacing: 0) {
                HStack {
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
                .padding(.horizontal)
                .padding(.top, 8)

                Picker("Tab", selection: $selectedTab) {
                    ForEach(FriendTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .friends:
                    friendsList
                case .groups:
                    groupsList
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedTab == .friends {
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if selectedTab == .friends {
                            showingFriendNew = true
                        } else {
                            showingGroupNew = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFriendNew) {
                FriendNewView()
            }
            .sheet(isPresented: $showingGroupNew) {
                GroupNewView()
            }
            .sheet(isPresented: $showingRedeemInvite) {
                RedeemInviteView()
            }
            .sheet(isPresented: $showingSignInRequired) {
                SignInRequiredView()
            }
        }
    }

    private var friendsList: some View {
        List {
            ForEach(Array(friends.enumerated()), id: \.element.persistentModelID) { index, friend in
                NavigationLink {
                    FriendDetailView(friend: friend)
                } label: {
                    VStack(spacing: 0) {
                        FriendRow(friend: friend, balance: balance(for: friend))
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
        }
        .overlay {
            if friends.isEmpty {
                ContentUnavailableView("No Friends", systemImage: "person.2", description: Text("Tap + to add your first friend."))
            }
        }
        .refreshable {
            await FriendSyncService.shared.pullFriends(into: modelContext)
        }
    }

    private var groupsList: some View {
        List {
            ForEach(groups) { group in
                NavigationLink {
                    GroupDetailView(group: group)
                } label: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        let total = expenses.filter { $0.group?.persistentModelID == group.persistentModelID }.reduce(0) { $0 + $1.amount }
                        Text(total, format: .currency(code: "NZD"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("No Groups", systemImage: "folder", description: Text("Tap + to create your first group."))
            }
        }
    }
}


#Preview {
    FriendView()
        .modelContainer(PreviewSampleData.container)
}
