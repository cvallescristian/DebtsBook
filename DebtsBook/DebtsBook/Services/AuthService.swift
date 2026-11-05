import Foundation
import UIKit
import Supabase
import Auth
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    private let client = SupabaseManager.shared.client
    private static let redirectURL = URL(string: "debtsbook://login-callback")

    var session: Session?
    var lastError: String?
    var isRestoringSession = true

    var isSignedIn: Bool { session != nil }

    /// Set once AccountOwnership confirms the local store belongs to the signed-in account.
    var confirmedOwnerID: UUID?

    /// The user ID sync is allowed to act as: nil until ownership is confirmed.
    var syncUserID: UUID? {
        guard let userID = session?.user.id, userID == confirmedOwnerID else { return nil }
        return userID
    }

    private var currentAppleNonce: String?

    private override init() {
        super.init()
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        guard !TestModelContainer.isUITesting else {
            isRestoringSession = false
            return
        }
        session = try? await client.auth.session
        isRestoringSession = false
    }

    func signInWithMagicLink(email: String) async {
        lastError = nil
        do {
            try await client.auth.signInWithOTP(email: email, redirectTo: Self.redirectURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func verifyOTP(email: String, code: String) async {
        lastError = nil
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            session = response.session
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handle(url: URL) {
        Task {
            do {
                session = try await client.auth.session(from: url)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Whether this account has a Sign in with Apple identity, whose tokens must be revoked
    /// when the account is deleted.
    var usesSignInWithApple: Bool {
        session?.user.identities?.contains { $0.provider == "apple" } ?? false
    }

    private struct DeleteAccountRequest: Encodable {
        let apple_authorization_code: String?
    }

    /// Permanently deletes the account and all its server data (delete-account Edge Function),
    /// then ends the session locally. The caller erases local data.
    func deleteAccount(appleAuthorizationCode: String?) async throws {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(method: .post, body: DeleteAccountRequest(apple_authorization_code: appleAuthorizationCode))
        )
        // The user no longer exists server-side, so this only clears the stored session.
        try? await client.auth.signOut()
        session = nil
        confirmedOwnerID = nil
    }

    func signOut() async {
        await NotificationService.shared.removeDeviceToken()
        try? await client.auth.signOut()
        session = nil
        confirmedOwnerID = nil
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        lastError = nil
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                lastError = "Could not sign in with Apple (missing token)."
                return
            }
            guard let nonce = currentAppleNonce else {
                lastError = "Could not sign in with Apple (missing nonce)."
                return
            }
            do {
                session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            } catch {
                lastError = error.localizedDescription
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                lastError = error.localizedDescription
            }
        }
        currentAppleNonce = nil
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < characters.count {
                result.append(characters[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
