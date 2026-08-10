import Foundation
import SwiftData
import Supabase
import Auth

private struct RemoteExpense: Decodable {
    let id: UUID
    let title: String
    let amount: Decimal
    let is_settled: Bool
    let paid_by_user_id: UUID?
    let split_type: String
    let comment: String?
    let date: Date
}

private struct ConnectionMembers: Decodable {
    let user_a: UUID
    let user_b: UUID?
}

private struct ExpenseUpsert: Encodable {
    let id: UUID
    let connection_id: UUID
    let title: String
    let amount: Decimal
    let is_settled: Bool
    let paid_by_user_id: UUID?
    let split_type: String
    let comment: String?
    let date: Date
}

@Observable
final class ExpenseSyncService {
    static let shared = ExpenseSyncService()

    private let client = SupabaseManager.shared.client
    var lastError: String?

    /// remoteIDs currently mid-upload via push(). Excluded from the reconcile-delete pass in
    /// pullExpenses so a pull racing a not-yet-uploaded create can't delete it out from under
    /// the in-flight push (which would then crash reading properties off the deleted model).
    private var pendingPushIDs: Set<UUID> = []

    private init() {}

    func pullExpenses(into context: ModelContext, for friend: Friend) async {
        // Require linkedUserID (not just connectionID) — a pending, not-yet-accepted
        // invite has nothing to pull yet, and pulling early risks reconciling against an
        // empty result before history is ever transferred.
        guard friend.linkedUserID != nil, let connectionID = friend.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        do {
            let remoteExpenses: [RemoteExpense] = try await client
                .from("expenses")
                .select("id, title, amount, is_settled, paid_by_user_id, split_type, comment, date")
                .eq("connection_id", value: connectionID)
                .execute()
                .value

            let existing = try context.fetch(FetchDescriptor<Expense>())
            let friendsSyncedExpenses = existing.filter {
                $0.friend?.persistentModelID == friend.persistentModelID && $0.remoteID != nil
            }
            let byRemoteID = Dictionary(uniqueKeysWithValues: friendsSyncedExpenses.compactMap { expense in
                expense.remoteID.map { ($0, expense) }
            })

            for remote in remoteExpenses {
                let paidByMe = remote.paid_by_user_id == currentUserID
                let splitType = SplitType(rawValue: remote.split_type) ?? .equally

                if let local = byRemoteID[remote.id] {
                    local.title = remote.title
                    local.amount = remote.amount
                    local.isSettled = remote.is_settled
                    local.paidByMe = paidByMe
                    local.splitType = splitType
                    local.comment = remote.comment
                    local.date = remote.date
                } else {
                    let expense = Expense(
                        title: remote.title,
                        amount: remote.amount,
                        friend: friend,
                        paidByMe: paidByMe,
                        splitType: splitType,
                        date: remote.date,
                        comment: remote.comment
                    )
                    expense.remoteID = remote.id
                    expense.isSettled = remote.is_settled
                    context.insert(expense)
                }
            }

            // Server is authoritative for synced expenses: anything previously synced for
            // this friend that's no longer in the fresh fetch was deleted (or belongs to a
            // now-dead connection) and should disappear locally too.
            let remoteIDs = Set(remoteExpenses.map { $0.id })
            for expense in friendsSyncedExpenses {
                let expenseRemoteID = expense.remoteID!
                if !remoteIDs.contains(expenseRemoteID) && !pendingPushIDs.contains(expenseRemoteID) {
                    context.delete(expense)
                }
            }

            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Resolves the other member of a connection directly from the `connections` table —
    /// the single source of truth for who's actually in it — rather than trusting a
    /// locally-cached `linkedUserID` that can go stale (e.g. before the invite is redeemed,
    /// or if a prior sync bug left it wrong). Returns nil if the connection has no second
    /// member yet (not redeemed).
    private func resolveOtherMember(of connectionID: UUID, excluding currentUserID: UUID) async -> UUID? {
        do {
            let members: ConnectionMembers = try await client
                .from("connections")
                .select("user_a, user_b")
                .eq("id", value: connectionID)
                .single()
                .execute()
                .value
            return members.user_a == currentUserID ? members.user_b : members.user_a
        } catch {
            return nil
        }
    }

    func push(expense: Expense) async {
        // Require linkedUserID (not just connectionID) — while the invite is still
        // pending, the friend's real ID doesn't exist anywhere yet, so any "friend paid"
        // expense would resolve to an unknown payer. Wait until accepted; pullFriends
        // pushes everything in one go the moment that happens.
        guard expense.friend?.linkedUserID != nil else { return }
        guard let connectionID = expense.friend?.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        let remoteID = expense.remoteID ?? UUID()
        expense.remoteID = remoteID
        let paidByUserID = expense.paidByMe ? currentUserID : await resolveOtherMember(of: connectionID, excluding: currentUserID)
        let upsert = ExpenseUpsert(
            id: remoteID,
            connection_id: connectionID,
            title: expense.title,
            amount: expense.amount,
            is_settled: expense.isSettled,
            paid_by_user_id: paidByUserID,
            split_type: expense.splitType.rawValue,
            comment: expense.comment,
            date: expense.date
        )
        pendingPushIDs.insert(remoteID)
        defer { pendingPushIDs.remove(remoteID) }
        do {
            try await client.from("expenses").upsert(upsert).execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pushAll(for friend: Friend, expenses: [Expense]) async {
        for expense in expenses where expense.friend?.persistentModelID == friend.persistentModelID {
            await push(expense: expense)
        }
    }

    func delete(expense: Expense) async {
        guard let remoteID = expense.remoteID else { return }
        do {
            try await client.from("expenses").delete().eq("id", value: remoteID).execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
