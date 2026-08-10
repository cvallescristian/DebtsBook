import Foundation
import SwiftData
import Supabase
import Auth

private struct ConnectionInsert: Encodable {
    let id: UUID
    let user_a: UUID
}

private struct InviteInsert: Encodable {
    let code: String
    let inviter_id: UUID
    let connection_id: UUID
    let expires_at: Date
}

private struct RedeemParams: Encodable {
    let invite_code: String
}

@Observable
final class ConnectService {
    static let shared = ConnectService()

    private let client = SupabaseManager.shared.client
    var lastError: String?

    private init() {}

    /// Creates (or reuses) the shared connection for `friend`, transfers their existing
    /// expense history into it, and returns a redeemable invite code.
    func createInvite(for friend: Friend, expenses: [Expense]) async -> String? {
        guard let userID = AuthService.shared.session?.user.id else { return nil }
        do {
            let connectionID: UUID
            if let existing = friend.connectionID {
                connectionID = existing
            } else {
                let newID = UUID()
                try await client.from("connections").insert(ConnectionInsert(id: newID, user_a: userID)).execute()
                friend.connectionID = newID
                connectionID = newID
            }

            await FriendSyncService.shared.push(friend: friend)
            await ExpenseSyncService.shared.pushAll(for: friend, expenses: expenses)

            let code = Self.generateCode()
            let invite = InviteInsert(code: code, inviter_id: userID, connection_id: connectionID, expires_at: Date().addingTimeInterval(60 * 60 * 24))
            try await client.from("invites").insert(invite).execute()
            lastError = nil
            return code
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func redeemInvite(code: String) async -> Bool {
        do {
            try await client.rpc("redeem_invite", params: RedeemParams(invite_code: code)).execute()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private static func generateCode(length: Int = 6) -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}
