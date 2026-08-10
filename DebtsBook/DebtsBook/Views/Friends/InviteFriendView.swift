import SwiftUI
import SwiftData

struct InviteFriendView: View {

    let friend: Friend
    let expenses: [Expense]

    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                } else if let code {
                    Text("Share this code")
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
            .task {
                code = await ConnectService.shared.createInvite(for: friend, expenses: expenses)
                errorMessage = ConnectService.shared.lastError
                isLoading = false
            }
        }
    }
}


#Preview {
    InviteFriendView(friend: PreviewSampleData.friend, expenses: [])
        .modelContainer(PreviewSampleData.container)
}
