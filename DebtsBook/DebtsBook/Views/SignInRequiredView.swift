import SwiftUI

struct SignInRequiredView: View {

    @Environment(\.dismiss) private var dismiss
    private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            AuthView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onChange(of: authService.isSignedIn) { _, isSignedIn in
                    if isSignedIn { dismiss() }
                }
        }
    }
}

#Preview {
    SignInRequiredView()
}
