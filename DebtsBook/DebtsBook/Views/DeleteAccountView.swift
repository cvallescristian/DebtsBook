import SwiftUI
import SwiftData
import AuthenticationServices

/// In-app account deletion (App Store guideline 5.1.1(v)). Accounts using Sign in with Apple
/// confirm with Apple once more, which provides the code needed to revoke their Apple login.
struct DeleteAccountView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var didDelete = false
    private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Your account and everything saved to it are permanently deleted from our servers: friends, expenses, groups, budgets and activity.", systemImage: "trash")
                    Label("Friends you're linked with lose the expenses you shared with them.", systemImage: "person.2.slash")
                    Label("This iPhone is erased too. Export a backup first if you want to keep a copy.", systemImage: "iphone")
                } footer: {
                    Text("This can't be undone.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    if isDeleting {
                        HStack {
                            ProgressView()
                            Text("Deleting your account…")
                        }
                    } else if authService.usesSignInWithApple {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = []
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .frame(height: 44)
                    } else {
                        Button("Delete Account", role: .destructive) {
                            showingConfirmation = true
                        }
                    }
                } footer: {
                    if authService.usesSignInWithApple && !isDeleting {
                        Text("Confirm with Apple to delete your account.")
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
            .confirmationModal(
                isPresented: $showingConfirmation,
                title: "Delete your account?",
                message: "This permanently deletes your account and all its data. This action cannot be undone.",
                confirmLabel: "Delete Account",
                successMessage: "Account deleted",
                onConfirm: {
                    await deleteAccount(appleAuthorizationCode: nil)
                },
                onDismiss: {
                    if didDelete {
                        dismiss()
                    }
                }
            )
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = credential.authorizationCode,
                  let code = String(data: codeData, encoding: .utf8) else {
                errorMessage = "Couldn't confirm with Apple. Please try again."
                return
            }
            isDeleting = true
            Task {
                if await deleteAccount(appleAuthorizationCode: code) {
                    dismiss()
                }
                isDeleting = false
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Returns whether the account was deleted; on failure the error shows on this screen.
    private func deleteAccount(appleAuthorizationCode: String?) async -> Bool {
        errorMessage = nil
        do {
            try await authService.deleteAccount(appleAuthorizationCode: appleAuthorizationCode)
            AccountOwnership.eraseLocalData(in: modelContext)
            AccountOwnership.owner = nil
            didDelete = true
            return true
        } catch {
            errorMessage = "Couldn't delete your account. Check your connection and try again."
            return false
        }
    }
}

#Preview {
    DeleteAccountView()
        .modelContainer(PreviewSampleData.container)
}
