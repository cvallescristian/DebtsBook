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

    private init() {}

    func pullExpenses(into context: ModelContext, for friend: Friend) async {
        guard let connectionID = friend.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        do {
            let remoteExpenses: [RemoteExpense] = try await client
                .from("expenses")
                .select("id, title, amount, is_settled, paid_by_user_id, split_type, comment, date")
                .eq("connection_id", value: connectionID)
                .execute()
                .value

            let existing = try context.fetch(FetchDescriptor<Expense>())
            let byRemoteID = Dictionary(uniqueKeysWithValues: existing.compactMap { expense in
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
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func push(expense: Expense) async {
        guard let connectionID = expense.friend?.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        let remoteID = expense.remoteID ?? UUID()
        expense.remoteID = remoteID
        let paidByUserID = expense.paidByMe ? currentUserID : expense.friend?.linkedUserID
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
