import SwiftUI
import SwiftData

struct FriendDetailView: View {

    let friend: Friend
    @State private var showingFriendEdit: Bool = false
    @State private var showingExpenseNew: Bool = false
    @State private var editingExpense: Expense?
    @State private var showingSettleUpConfirmation: Bool = false
    @State private var showingInviteFriend: Bool = false
    @State private var showingDisconnectConfirmation: Bool = false
    @State private var showingSignInRequired: Bool = false
    @State private var isSyncingExpenses: Bool = false
    @State private var showingDisconnectError: Bool = false
    @State private var selectedRange: BudgetPeriod = .week
    @State private var periodOffset: Int = 0
    @Environment(\.expandFriendAvatar) private var expandFriendAvatar
    var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var activities: [Activity]

    private var friendsExpenses: [Expense] {
        expenses
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .sorted { $0.date > $1.date }
    }

    private var friendsActivities: [Activity] {
        activities
            .filter { $0.friend?.persistentModelID == friend.persistentModelID }
            .sorted { $0.date > $1.date }
    }

    private static let previewCount = 10

    private var selectedInterval: DateInterval {
        selectedRange.dateInterval(offset: periodOffset)
    }

    private var expensesInPeriod: [Expense] {
        friendsExpenses.dated(in: selectedInterval)
    }

    private var balance: Decimal {
        friendsExpenses.netBalance
    }

    private var hasUnsettledExpenses: Bool {
        friendsExpenses.contains { !$0.isSettled }
    }

    private var hasUnsyncedData: Bool {
        guard friend.connectionID != nil && friend.linkedUserID != nil else { return false }
        return friendsExpenses.contains { $0.remoteID == nil } || friendsActivities.contains { $0.remoteID == nil }
    }

    var body: some View {
        List {
            VStack(spacing: 12) {
                Button {
                    expandFriendAvatar?(friend)
                } label: {
                    FriendAvatar(name: friend.name, photoData: friend.photoData, iconName: friend.iconName, size: 64)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(friend.name)'s photo")

                HStack {
                    if balance > 0 {
                        Text("Overall, you are owed")
                            .font(.title2)
                        Text(balance, format: .currency(code: "NZD"))
                            .foregroundColor(.green)
                            .font(Font.title2.bold())
                    } else if balance < 0 {
                        Text("Overall, you owe")
                            .font(.title2)
                        Text(-balance, format: .currency(code: "NZD"))
                            .foregroundColor(.red)
                            .font(Font.title2.bold())
                    } else {
                        Label("Settled up", systemImage: "hand.thumbsup.fill")
                            .font(.title2)
                    }
                }

                if hasUnsettledExpenses {
                    Button("Settle Up") {
                        showingSettleUpConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if friend.linkedUserID != nil, let lastSyncedAt = friend.lastSyncedAt {
                    Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if hasUnsyncedData {
                Button {
                    syncPendingData()
                } label: {
                    HStack {
                        if isSyncingExpenses {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncingExpenses ? "Syncing…" : "Some info hasn't synced yet. Tap to sync.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSyncingExpenses)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if friendsExpenses.isEmpty {
                ContentUnavailableView("No Expenses", systemImage: "dollarsign.circle", description: Text("Expenses with \(friend.name) will show up here."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                FriendPeriodCard(
                    range: $selectedRange,
                    offset: $periodOffset,
                    dates: friendsExpenses.map(\.date),
                    spentTogether: expensesInPeriod.totalAmount,
                    yourShare: expensesInPeriod.totalMyShare
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                Section {
                    if expensesInPeriod.isEmpty {
                        Text("No expenses this \(selectedRange.rawValue.lowercased()).")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(expensesInPeriod.prefix(Self.previewCount)) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                            .tint(.primary)
                            .settleSwipeAction(for: expense, in: modelContext)
                        }
                        if expensesInPeriod.count > Self.previewCount {
                            NavigationLink {
                                FriendExpenseListView(title: selectedRange.label(for: selectedInterval), expenses: expensesInPeriod)
                            } label: {
                                Text("See All (\(expensesInPeriod.count))")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        // Room for the floating Add Expense button, so it never covers the last row.
        .contentMargins(.bottom, 88, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingExpenseNew = true
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding()
        }
        .confirmationModal(
            isPresented: $showingSettleUpConfirmation,
            title: "Settle up with \(friend.name)?",
            message: "This marks all of \(friend.name)'s expenses as paid.",
            confirmLabel: "Settle Up",
            successMessage: "Settled up with \(friend.name)",
            isDestructive: false
        ) {
            settleUp()
        }
        .navigationTitle(friend.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if friend.connectionID == nil {
                    Button {
                        if authService.isSignedIn {
                            showingInviteFriend = true
                        } else {
                            showingSignInRequired = true
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                } else if friend.linkedUserID == nil {
                    Button {
                        showingInviteFriend = true
                    } label: {
                        Image(systemName: "hourglass")
                    }
                } else {
                    Button {
                        showingDisconnectConfirmation = true
                    } label: {
                        Image(systemName: "link.circle.fill")
                    }
                }
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                NavigationLink {
                    FriendActivityView(friend: friend)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Activity")

                Button {
                    showingFriendEdit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit Friend")
            }
        }
        .sheet(isPresented: $showingFriendEdit){
            FriendEditView(friend: friend, onDelete: { dismiss() })
        }
        .sheet(isPresented: $showingExpenseNew) {
            ExpenseNewView(friend: friend)
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
        .sheet(isPresented: $showingInviteFriend) {
            InviteFriendView(friend: friend)
        }
        .sheet(isPresented: $showingSignInRequired) {
            SignInRequiredView()
        }
        .confirmationModal(
            isPresented: $showingDisconnectConfirmation,
            title: "Disconnect from \(friend.name)?",
            message: "This stops syncing shared expenses between your accounts. You'll each keep your own copy of the history so far.",
            confirmLabel: "Disconnect",
            successMessage: "Disconnected from \(friend.name)"
        ) {
            let succeeded = await ConnectService.shared.disconnect(friend: friend, context: modelContext)
            if !succeeded {
                showingDisconnectError = true
            }
            return succeeded
        }
        .alert("Couldn't Disconnect", isPresented: $showingDisconnectError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ConnectService.shared.lastError ?? "Please check your connection and try again.")
        }
        .task {
            await refreshFromRemote()
        }
        .refreshable {
            await refreshFromRemote()
        }
    }

    private func refreshFromRemote() async {
        // pullFriends also detects a friend's linkedUserID newly resolving (their invite
        // just got redeemed) and re-pushes that friend's expenses/activities to fix up
        // anything that went out before the connection was fully established.
        await FriendSyncService.shared.pullFriends(into: modelContext)
        if friend.linkedUserID != nil {
            await ExpenseSyncService.shared.pullExpenses(into: modelContext, for: friend)
            await ActivitySyncService.shared.pullActivities(into: modelContext, for: friend)
        }
    }

    private func syncPendingData() {
        isSyncingExpenses = true
        Task {
            await ExpenseSyncService.shared.pushAll(for: friend, expenses: friendsExpenses)
            await ActivitySyncService.shared.pushAll(for: friend, activities: friendsActivities)
            isSyncingExpenses = false
        }
    }

    private func settleUp() {
        let settledAmount = balance
        let isConnected = friend.linkedUserID != nil
        for expense in friendsExpenses where !expense.isSettled {
            expense.isSettled = true
            if isConnected {
                Task { await ExpenseSyncService.shared.push(expense: expense) }
            }
        }
        let activity = Activity(type: .settledUp, expenseTitle: "", friendName: friend.name, amount: abs(settledAmount), paidByMe: settledAmount > 0, friend: friend)
        DataStore.insert(activity, into: modelContext)
        if isConnected {
            Task { await ActivitySyncService.shared.push(activity: activity) }
        }
    }
}

private struct FriendExpenseListView: View {
    let title: String
    let expenses: [Expense]
    @State private var editingExpense: Expense?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(expenses) { expense in
            Button {
                editingExpense = expense
            } label: {
                ExpenseRow(expense: expense)
            }
            .tint(.primary)
            .settleSwipeAction(for: expense, in: modelContext)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingExpense) { expense in
            ExpenseEditView(expense: expense)
        }
    }
}

/// One card for picking the period and seeing its totals: ‹ › to step, the title opens the
/// calendar (where the week/month/year range is chosen too), ↩ returns to now.
private struct FriendPeriodCard: View {
    @Binding var range: BudgetPeriod
    @Binding var offset: Int
    let dates: [Date]
    let spentTogether: Decimal
    let yourShare: Decimal

    @State private var showingPicker = false

    private var interval: DateInterval {
        range.dateInterval(offset: offset)
    }

    private var canGoBack: Bool {
        guard let oldest = dates.min() else { return false }
        return oldest < interval.start
    }

    private var title: String {
        switch offset {
        case 0: return "This \(range.rawValue)"
        case -1: return "Last \(range.rawValue)"
        default: return "\(-offset) \(range.rawValue)s Ago"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                arrow("chevron.left", label: "Previous \(range.rawValue)") {
                    offset -= 1
                }
                .disabled(!canGoBack)

                Button {
                    showingPicker = true
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(range.label(for: interval))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose a week, month or year")

                if offset != 0 {
                    arrow("arrow.uturn.forward", label: "Back to This \(range.rawValue)") {
                        offset = 0
                    }
                }

                arrow("chevron.right", label: "Next \(range.rawValue)") {
                    offset += 1
                }
                .disabled(offset == 0)
            }

            Divider()

            HStack {
                total("Spent together", spentTogether, alignment: .leading)
                Spacer()
                total("Your share", yourShare, alignment: .trailing)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.default, value: offset)
        .sheet(isPresented: $showingPicker) {
            ReportsPeriodPicker(range: range, selected: interval, spendingDates: dates, allowsRangeChange: true) { newRange, date in
                range = newRange
                offset = newRange.offset(of: date)
            }
        }
    }

    private func total(_ label: String, _ amount: Decimal, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "NZD"))
                .font(.title3.bold())
                .contentTransition(.numericText())
        }
    }

    private func arrow(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

private struct FriendActivityView: View {
    let friend: Friend
    @Query(sort: \Activity.date, order: .reverse) private var activities: [Activity]

    private var friendsActivities: [Activity] {
        activities.filter { $0.friend?.persistentModelID == friend.persistentModelID }
    }

    var body: some View {
        List(friendsActivities) { activity in
            ActivityRow(activity: activity)
        }
        .overlay {
            if friendsActivities.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath", description: Text("Changes you make will show up here."))
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview {
    NavigationStack {
        FriendDetailView(friend: PreviewSampleData.friend)
    }
    .modelContainer(PreviewSampleData.container)
}
