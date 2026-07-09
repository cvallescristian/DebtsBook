import SwiftUI
import LocalAuthentication

struct LockScreenView: View {

    let onUnlock: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("DebtsBook is Locked")
                .font(.title2.bold())

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Unlock") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .task {
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var evaluationError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            errorMessage = evaluationError?.localizedDescription ?? "Authentication is not available on this device."
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock DebtsBook") { success, error in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                } else {
                    errorMessage = error?.localizedDescription
                }
            }
        }
    }
}


#Preview {
    LockScreenView(onUnlock: {})
}
