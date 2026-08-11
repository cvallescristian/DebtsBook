import SwiftUI
import SwiftData

struct InviteFriendView: View {

    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCancelConfirmation = false
    @State private var isCancelling = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                } else if let code {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Invite Pending")
                        .font(.headline)
                    Text(code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    Text("This shares all your expense history with \(friend.name) once redeemed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    ShareLink(item: "Connect with me on DebtsBook using code \(code)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showingCancelConfirmation = true
                    } label: {
                        if isCancelling {
                            ProgressView()
                        } else {
                            Text("Cancel Invite")
                        }
                    }
                    .disabled(isCancelling)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Invite a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationModal(
                isPresented: $showingCancelConfirmation,
                title: "Cancel this invite?",
                message: "The code will stop working and \(friend.name) will no longer be able to redeem it.",
                confirmLabel: "Cancel Invite",
                successMessage: "Invite cancelled",
                onConfirm: { cancelInvite() },
                onDismiss: { dismiss() }
            )
            .task {
                code = await ConnectService.shared.pendingInviteCode(for: friend)
                if code == nil {
                    code = await ConnectService.shared.createInvite(for: friend)
                    errorMessage = ConnectService.shared.lastError
                }
                isLoading = false
            }
        }
    }

    private func cancelInvite() {
        isCancelling = true
        Task {
            _ = await ConnectService.shared.disconnect(friend: friend, context: modelContext)
            isCancelling = false
        }
    }
}


#Preview {
    InviteFriendView(friend: PreviewSampleData.friend)
        .modelContainer(PreviewSampleData.container)
}
