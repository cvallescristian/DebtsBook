import SwiftUI
import SwiftData

struct RedeemInviteView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code: String = ""
    @State private var isRedeeming = false
    @State private var errorMessage: String?
    @State private var newlyConnectedFriend: Friend?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Enter Invite Code")
                    .font(.title2.bold())

                Text("Paste the code your friend shared with you to connect your accounts and sync expenses.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Invite Code", text: $code)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.medium).monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .authFieldStyle()
                    .padding(.top, 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    redeem()
                } label: {
                    if isRedeeming {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(code.isEmpty || isRedeeming)

                Spacer()
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $newlyConnectedFriend, onDismiss: { dismiss() }) { friend in
                FriendEditView(friend: friend)
            }
        }
    }

    private func redeem() {
        errorMessage = nil
        isRedeeming = true
        Task {
            let existingRemoteIDs = Set(((try? modelContext.fetch(FetchDescriptor<Friend>())) ?? []).compactMap(\.remoteID))
            let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let success = await ConnectService.shared.redeemInvite(code: trimmedCode)
            if success {
                await FriendSyncService.shared.pullFriends(into: modelContext)
                let allFriends = (try? modelContext.fetch(FetchDescriptor<Friend>())) ?? []
                let connectedFriends = allFriends.filter { $0.connectionID != nil }
                for friend in connectedFriends {
                    await ExpenseSyncService.shared.pullExpenses(into: modelContext, for: friend)
                    await ActivitySyncService.shared.pullActivities(into: modelContext, for: friend)
                }
                if let newFriend = allFriends.first(where: { friend in
                    guard let remoteID = friend.remoteID else { return false }
                    return !existingRemoteIDs.contains(remoteID)
                }) {
                    newlyConnectedFriend = newFriend
                } else {
                    dismiss()
                }
            } else {
                errorMessage = ConnectService.shared.lastError ?? "Could not redeem this code."
            }
            isRedeeming = false
        }
    }
}


#Preview {
    RedeemInviteView()
        .modelContainer(PreviewSampleData.container)
}
