import SwiftUI
import SwiftData

struct RedeemInviteView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code: String = ""
    @State private var isRedeeming = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Invite Code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
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
                .disabled(code.isEmpty || isRedeeming)
            }
            .padding()
            .navigationTitle("Enter Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func redeem() {
        errorMessage = nil
        isRedeeming = true
        Task {
            let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let success = await ConnectService.shared.redeemInvite(code: trimmedCode)
            if success {
                await FriendSyncService.shared.pullFriends(into: modelContext)
                let connectedFriends = (try? modelContext.fetch(FetchDescriptor<Friend>()))?.filter { $0.connectionID != nil } ?? []
                for friend in connectedFriends {
                    await ExpenseSyncService.shared.pullExpenses(into: modelContext, for: friend)
                }
                dismiss()
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
