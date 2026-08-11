import SwiftUI

struct AuthView: View {

    @State private var email: String = ""
    @State private var isSending = false
    @State private var linkSent = false
    @State private var errorMessage: String?
    @State private var code: String = ""
    @State private var isVerifyingCode = false
    private var authService = AuthService.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sign in to DebtsBook")
                .font(.title2.bold())

            if linkSent {
                Text("Check \(email) for a 8-digit code (or a sign-in link).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("8-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.medium))
                    .authFieldStyle()

                if let callbackError = authService.lastError {
                    Text(callbackError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    verifyCode()
                } label: {
                    if isVerifyingCode {
                        ProgressView()
                    } else {
                        Text("Verify Code")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(code.isEmpty || isVerifyingCode)

                Button("Use a different email") {
                    linkSent = false
                    code = ""
                }
                .buttonStyle(.bordered)
            } else {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .authFieldStyle()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    sendLink()
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Send Sign-In Link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || isSending)
            }
        }
        .padding()
    }

    private func verifyCode() {
        isVerifyingCode = true
        Task {
            await authService.verifyOTP(email: email, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            isVerifyingCode = false
        }
    }

    private func sendLink() {
        errorMessage = nil
        isSending = true
        Task {
            await authService.signInWithMagicLink(email: email)
            isSending = false
            if let error = authService.lastError {
                errorMessage = error
            } else {
                linkSent = true
            }
        }
    }
}


#Preview {
    AuthView()
}
