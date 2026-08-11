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

private struct DeletedConnection: Decodable {
    let id: UUID
}

private struct PendingInvite: Decodable {
    let code: String
}

@Observable
final class ConnectService {
    static let shared = ConnectService()

    private let client = SupabaseManager.shared.client
    var lastError: String?

    private init() {}

    /// Creates (or reuses) the shared connection for `friend` and returns a redeemable
    /// invite code. Expense history is deliberately NOT transferred yet — the other person
    /// hasn't redeemed the code, so their real account ID doesn't exist anywhere yet, and
    /// any "friend paid" expense pushed now would resolve to an unknown payer. Once they
    /// redeem, FriendSyncService.pullFriends notices the connection just became accepted
    /// (linkedUserID resolves) and pushes the full history at that point instead.
    func createInvite(for friend: Friend) async -> String? {
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

    /// Returns the still-valid, unredeemed invite code for `friend`'s connection, if any —
    /// so reopening the invite sheet on a pending connection shows the same code instead of
    /// minting a new one (and leaving the old one dangling, redeemable, and confusing).
    func pendingInviteCode(for friend: Friend) async -> String? {
        guard let connectionID = friend.connectionID,
              let userID = AuthService.shared.session?.user.id else { return nil }
        do {
            let invites: [PendingInvite] = try await client
                .from("invites")
                .select("code")
                .eq("connection_id", value: connectionID)
                .eq("inviter_id", value: userID)
                .eq("redeemed", value: false)
                .gt("expires_at", value: Date())
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return invites.first?.code
        } catch {
            return nil
        }
    }

    /// Deletes the shared connection (cascades to its expenses in Supabase) and clears the
    /// local link. Each side keeps their own copy of the expense history synced so far.
    func disconnect(friend: Friend, context: ModelContext) async -> Bool {
        guard let connectionID = friend.connectionID else { return true }
        do {
            let deleted: [DeletedConnection] = try await client
                .from("connections")
                .delete()
                .eq("id", value: connectionID)
                .select("id")
                .execute()
                .value
            guard !deleted.isEmpty else {
                lastError = "Could not disconnect — the connection may have already been removed, or you don't have permission."
                return false
            }
            friend.connectionID = nil
            friend.linkedUserID = nil
            await FriendSyncService.shared.push(friend: friend)
            // The remote rows just got cascade-deleted along with the connection, so any
            // remoteID pointing at them is now stale. Clear it so a future reconnect treats
            // this history as unsynced instead of reusing dead remote IDs — reusing them let
            // a racing pullExpenses see "remoteID set but not found remotely" and delete the
            // local expense before the reconnect's push had a chance to land.
            let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
            for expense in expenses where expense.friend?.persistentModelID == friend.persistentModelID {
                expense.remoteID = nil
            }
            let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
            for activity in activities where activity.friend?.persistentModelID == friend.persistentModelID {
                activity.remoteID = nil
            }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
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
