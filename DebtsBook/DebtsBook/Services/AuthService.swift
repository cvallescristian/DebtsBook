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

    private var currentAppleNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        Task { await restoreSession() }
    }

    private func restoreSession() async {
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
        print("AuthService.handle received URL: \(url.absoluteString)")
        Task {
            do {
                session = try await client.auth.session(from: url)
                print("AuthService.handle succeeded, user: \(session?.user.email ?? "nil")")
            } catch {
                print("AuthService.handle failed: \(error)")
                lastError = error.localizedDescription
            }
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
    }

    func signInWithApple() async {
        lastError = nil
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        await withCheckedContinuation { continuation in
            appleSignInContinuation = continuation
            controller.performRequests()
        }
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

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer {
            appleSignInContinuation?.resume()
            appleSignInContinuation = nil
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentAppleNonce else {
            lastError = "Could not sign in with Apple."
            return
        }
        Task {
            do {
                session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code != .canceled {
            lastError = error.localizedDescription
        }
        appleSignInContinuation?.resume()
        appleSignInContinuation = nil
    }
}
