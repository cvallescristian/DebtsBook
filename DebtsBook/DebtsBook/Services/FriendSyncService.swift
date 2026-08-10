import Foundation
import SwiftData
import Supabase
import Auth

private struct RemoteFriend: Decodable {
    let id: UUID
    let name: String
    let linked_user_id: UUID?
    let connection_id: UUID?
}

private struct FriendUpsert: Encodable {
    let id: UUID
    let owner_id: UUID
    let name: String
    let connection_id: UUID?
}

@Observable
final class FriendSyncService {
    static let shared = FriendSyncService()

    private let client = SupabaseManager.shared.client
    var lastError: String?

    private init() {}

    func pullFriends(into context: ModelContext) async {
        guard let userID = AuthService.shared.session?.user.id else { return }
        do {
            let remoteFriends: [RemoteFriend] = try await client
                .from("friends")
                .select("id, name, linked_user_id, connection_id")
                .eq("owner_id", value: userID)
                .execute()
                .value

            let existing = try context.fetch(FetchDescriptor<Friend>())
            let byRemoteID = Dictionary(uniqueKeysWithValues: existing.compactMap { friend in
                friend.remoteID.map { ($0, friend) }
            })

            var newlyLinkedFriends: [Friend] = []

            for remote in remoteFriends {
                if let local = byRemoteID[remote.id] {
                    let hadLinkedUser = local.linkedUserID != nil
                    local.name = remote.name
                    local.linkedUserID = remote.linked_user_id
                    local.connectionID = remote.connection_id
                    if !hadLinkedUser && local.linkedUserID != nil {
                        newlyLinkedFriends.append(local)
                    }
                } else {
                    let friend = Friend(name: remote.name)
                    friend.remoteID = remote.id
                    friend.linkedUserID = remote.linked_user_id
                    friend.connectionID = remote.connection_id
                    context.insert(friend)
                }
            }
            lastError = nil

            // A friend's linkedUserID resolving for the first time means a pending invite
            // just got redeemed. Any expense pushed before that point (the history transfer
            // at invite-creation, or any "friend paid" expense pushed while still pending)
            // went out with an unresolved paid_by_user_id — re-push everything for that
            // friend now that the connection is fully established to correct it.
            if !newlyLinkedFriends.isEmpty {
                let allExpenses = try context.fetch(FetchDescriptor<Expense>())
                for friend in newlyLinkedFriends {
                    let friendExpenses = allExpenses.filter { $0.friend?.persistentModelID == friend.persistentModelID }
                    await ExpenseSyncService.shared.pushAll(for: friend, expenses: friendExpenses)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func push(friend: Friend) async {
        guard let userID = AuthService.shared.session?.user.id else { return }
        let remoteID = friend.remoteID ?? UUID()
        friend.remoteID = remoteID
        do {
            try await client
                .from("friends")
                .upsert(FriendUpsert(id: remoteID, owner_id: userID, name: friend.name, connection_id: friend.connectionID))
                .execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(friend: Friend) async {
        guard let remoteID = friend.remoteID else { return }
        do {
            try await client.from("friends").delete().eq("id", value: remoteID).execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
