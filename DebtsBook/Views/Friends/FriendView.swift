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
    @Query private var friends: [Friend]
    @Query private var expenses: [Expense]
    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

    private func balance(for friend: Friend) -> Decimal {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .netBalance
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .sheet(isPresented: $showingFriendNew) {
                FriendNewView()
            }
            .sheet(isPresented: $showingGroupNew) {
                GroupNewView()
            }
        }
    }

    private var friendsList: some View {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .overlay {
            if friends.isEmpty {
                ContentUnavailableView("No Friends", systemImage: "person.2", description: Text("Tap + to add your first friend."))
            }
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
