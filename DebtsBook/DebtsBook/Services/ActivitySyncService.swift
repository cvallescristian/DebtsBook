import Foundation
import SwiftData
import Supabase
import Auth

private struct RemoteActivity: Decodable {
    let id: UUID
    let type: String
    let expense_title: String
    let amount: Decimal
    let actor_user_id: UUID?
    let paid_by_user_id: UUID?
    let date: Date
}

private struct ActivityUpsert: Encodable {
    let id: UUID
    let connection_id: UUID
    let type: String
    let expense_title: String
    let amount: Decimal
    let actor_user_id: UUID?
    let paid_by_user_id: UUID?
    let date: Date
}

@Observable
final class ActivitySyncService {
    static let shared = ActivitySyncService()

    private let client = SupabaseManager.shared.client
    var lastError: String?

    /// Same race guard as ExpenseSyncService.pendingPushIDs — excludes an in-flight push's
    /// remoteID from the reconcile-delete pass in pullActivities.
    private var pendingPushIDs: Set<UUID> = []
    private let pendingPushLock = NSLock()

    private init() {}

    private func markPendingPush(_ remoteID: UUID) {
        pendingPushLock.withLock { _ = pendingPushIDs.insert(remoteID) }
    }

    private func isPendingPush(_ remoteID: UUID) -> Bool {
        pendingPushLock.withLock { pendingPushIDs.contains(remoteID) }
    }

    private func clearPendingPush(_ remoteID: UUID) {
        pendingPushLock.withLock { _ = pendingPushIDs.remove(remoteID) }
    }

    func pullActivities(into context: ModelContext, for friend: Friend) async {
        guard friend.linkedUserID != nil, let connectionID = friend.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        do {
            let remoteActivities: [RemoteActivity] = try await client
                .from("activities")
                .select("id, type, expense_title, amount, actor_user_id, paid_by_user_id, date")
                .eq("connection_id", value: connectionID)
                .execute()
                .value

            let existing = try context.fetch(FetchDescriptor<Activity>())
            let friendsSyncedActivities = existing.filter {
                $0.friend?.persistentModelID == friend.persistentModelID && $0.remoteID != nil
            }
            let byRemoteID = Dictionary(uniqueKeysWithValues: friendsSyncedActivities.compactMap { activity in
                activity.remoteID.map { ($0, activity) }
            })

            for remote in remoteActivities {
                let performedByMe = remote.actor_user_id == currentUserID
                let paidByMe = remote.paid_by_user_id == currentUserID
                let type = ActivityType(rawValue: remote.type) ?? .created

                if let local = byRemoteID[remote.id] {
                    local.type = type
                    local.expenseTitle = remote.expense_title
                    local.amount = remote.amount
                    local.paidByMe = paidByMe
                    local.performedByMe = performedByMe
                    local.date = remote.date
                } else {
                    let activity = Activity(
                        type: type,
                        expenseTitle: remote.expense_title,
                        friendName: friend.name,
                        amount: remote.amount,
                        paidByMe: paidByMe,
                        performedByMe: performedByMe,
                        friend: friend,
                        date: remote.date
                    )
                    activity.remoteID = remote.id
                    context.insert(activity)
                }
            }

            // Same server-authoritative reconciliation as expenses: a synced activity no
            // longer present remotely (deleted, or its connection was torn down) disappears
            // locally too — unless it's mid-upload right now.
            let remoteIDs = Set(remoteActivities.map { $0.id })
            for activity in friendsSyncedActivities {
                let activityRemoteID = activity.remoteID!
                if !remoteIDs.contains(activityRemoteID) && !isPendingPush(activityRemoteID) {
                    context.delete(activity)
                }
            }

            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func push(activity: Activity) async {
        // Same guard as ExpenseSyncService.push(expense:) — nothing to resolve the paid-by
        // direction against until the connection is actually accepted.
        guard activity.friend?.linkedUserID != nil else { return }
        guard let connectionID = activity.friend?.connectionID else { return }
        guard let currentUserID = AuthService.shared.session?.user.id else { return }
        let remoteID = activity.remoteID ?? UUID()
        activity.remoteID = remoteID
        markPendingPush(remoteID)
        defer { clearPendingPush(remoteID) }
        // The actor is always whoever's device is pushing this — an Activity is only ever
        // pushed right after the local device itself performed the action. paidByMe is a
        // separate, direction-of-debt concept (mirrors expenses.paid_by_user_id) and needs
        // its own resolution — conflating the two previously made every synced entry read as
        // if the OTHER side had performed the action whenever paidByMe happened to be false.
        let paidByUserID = activity.paidByMe
            ? currentUserID
            : await ExpenseSyncService.shared.resolveOtherMember(of: connectionID, excluding: currentUserID)
        let upsert = ActivityUpsert(
            id: remoteID,
            connection_id: connectionID,
            type: activity.type.rawValue,
            expense_title: activity.expenseTitle,
            amount: activity.amount,
            actor_user_id: currentUserID,
            paid_by_user_id: paidByUserID,
            date: activity.date
        )
        do {
            try await client.from("activities").upsert(upsert).execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pushAll(for friend: Friend, activities: [Activity]) async {
        for activity in activities
        where activity.friend?.persistentModelID == friend.persistentModelID && activity.performedByMe {
            await push(activity: activity)
        }
    }

    func delete(activity: Activity) async {
        guard let remoteID = activity.remoteID else { return }
        await delete(remoteID: remoteID)
    }

    func delete(remoteID: UUID) async {
        do {
            try await client.from("activities").delete().eq("id", value: remoteID).execute()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
