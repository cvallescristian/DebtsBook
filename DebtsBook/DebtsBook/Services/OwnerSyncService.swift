import Foundation
import SwiftData
import Supabase

// Syncs everything that isn't shared through a connection (friends, groups, budgets, and
// expenses/activity that are personal or with a not-yet-linked friend) to the owner-only
// tables from migrations 0010/0011, using dirty flags, tombstones and a pull-since cursor.
//
// The connection-shared `expenses`/`activities` stay on ExpenseSyncService/ActivitySyncService
// (hard deletes + reconcile) until builds that don't understand `deleted_at` are gone: an
// older build would keep showing a soft-deleted shared expense forever.

/// The server side of owner sync. SupabaseSyncBackend in the app, a fake in tests.
protocol SyncBackend {
    func upsert<Row: Encodable>(_ rows: [Row], into table: String) async throws
    func markDeleted(_ ids: [UUID], in table: String) async throws
    /// Rows changed after `since` (all rows when nil), tombstones included.
    func fetchChanged<Row: Decodable>(_ table: String, since: Date?) async throws -> [Row]
}

struct SupabaseSyncBackend: SyncBackend {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct DeletedAt: Encodable {
        let deleted_at: Date
    }

    func upsert<Row: Encodable>(_ rows: [Row], into table: String) async throws {
        guard !rows.isEmpty else { return }
        try await client.from(table).upsert(rows).execute()
    }

    func markDeleted(_ ids: [UUID], in table: String) async throws {
        guard !ids.isEmpty else { return }
        try await client.from(table)
            .update(DeletedAt(deleted_at: Date()))
            .in("id", values: ids.map(\.uuidString))
            .execute()
    }

    func fetchChanged<Row: Decodable>(_ table: String, since: Date?) async throws -> [Row] {
        var query = client.from(table).select()
        if let since {
            query = query.gt("updated_at", value: since.ISO8601Format(.iso8601.time(includingFractionalSeconds: true)))
        }
        return try await query.order("updated_at").execute().value
    }
}

// MARK: - Rows

/// Every owner row decodes these; `updated_at` is the cursor, `deleted_at` the tombstone.
protocol OwnerRow: Decodable {
    var id: UUID { get }
    var updated_at: Date? { get }
    var deleted_at: Date? { get }
}

/// Nullable columns are encoded as explicit nulls, so clearing a field (e.g. removing an
/// expense's group) reaches the server instead of being skipped by encodeIfPresent.
private extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

struct SyncFriendRow: Encodable {
    let id: UUID
    let owner_id: UUID
    let name: String
    let connection_id: UUID?
    let icon_name: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(owner_id, forKey: .owner_id)
        try c.encode(name, forKey: .name)
        try c.encodeNullable(connection_id, forKey: .connection_id)
        try c.encodeNullable(icon_name, forKey: .icon_name)
    }

    private enum CodingKeys: String, CodingKey {
        case id, owner_id, name, connection_id, icon_name
    }
}

struct GroupRow: Codable, OwnerRow {
    let id: UUID
    var owner_id: UUID?
    let name: String
    var updated_at: Date?
    var deleted_at: Date?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(owner_id, forKey: .owner_id)
        try c.encode(name, forKey: .name)
    }
}

struct BudgetRow: Codable, OwnerRow {
    let id: UUID
    var owner_id: UUID?
    let group_id: UUID?
    let amount: Decimal
    let period: String
    var updated_at: Date?
    var deleted_at: Date?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(owner_id, forKey: .owner_id)
        try c.encodeNullable(group_id, forKey: .group_id)
        try c.encode(amount, forKey: .amount)
        try c.encode(period, forKey: .period)
    }
}

struct PersonalExpenseRow: Codable, OwnerRow {
    let id: UUID
    var owner_id: UUID?
    let group_id: UUID?
    let friend_id: UUID?
    let title: String
    let amount: Decimal
    let comment: String?
    let date: Date
    let paid_by_me: Bool
    let split_type: String
    let is_settled: Bool
    var updated_at: Date?
    var deleted_at: Date?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(owner_id, forKey: .owner_id)
        try c.encodeNullable(group_id, forKey: .group_id)
        try c.encodeNullable(friend_id, forKey: .friend_id)
        try c.encode(title, forKey: .title)
        try c.encode(amount, forKey: .amount)
        try c.encodeNullable(comment, forKey: .comment)
        try c.encode(date, forKey: .date)
        try c.encode(paid_by_me, forKey: .paid_by_me)
        try c.encode(split_type, forKey: .split_type)
        try c.encode(is_settled, forKey: .is_settled)
    }
}

struct PersonalActivityRow: Codable, OwnerRow {
    let id: UUID
    var owner_id: UUID?
    let friend_id: UUID?
    let friend_name: String?
    let type: String
    let expense_title: String
    let amount: Decimal
    let paid_by_me: Bool
    let date: Date
    var updated_at: Date?
    var deleted_at: Date?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeNullable(owner_id, forKey: .owner_id)
        try c.encodeNullable(friend_id, forKey: .friend_id)
        try c.encodeNullable(friend_name, forKey: .friend_name)
        try c.encode(type, forKey: .type)
        try c.encode(expense_title, forKey: .expense_title)
        try c.encode(amount, forKey: .amount)
        try c.encode(paid_by_me, forKey: .paid_by_me)
        try c.encode(date, forKey: .date)
    }
}

// MARK: - Engine

@MainActor
struct OwnerSyncService {
    let backend: SyncBackend
    let context: ModelContext
    let ownerID: UUID
    var defaults: UserDefaults = .standard

    /// Pulls re-read this much before the cursor: a row committed slightly out of order
    /// (server clock vs. transaction commit) would otherwise be skipped for good.
    static let cursorOverlap: TimeInterval = 60

    static let pushOrder = ["friends", "expense_groups", "budgets", "personal_expenses", "personal_activities"]
    static let pulledTables = ["expense_groups", "budgets", "personal_expenses", "personal_activities"]

    func sync() async throws {
        try await push()
        try await pull()
    }

    // MARK: Cursor

    private func cursorKey(_ table: String) -> String {
        "syncCursor.\(ownerID.uuidString).\(table)"
    }

    func cursor(for table: String) -> Date? {
        defaults.object(forKey: cursorKey(table)) as? Date
    }

    private func setCursor(_ date: Date, for table: String) {
        defaults.set(date, forKey: cursorKey(table))
    }

    /// A table that has never been pulled for this owner: everything local uploads once,
    /// so data created signed out (or before this build) reaches the server.
    private func isFirstSync(_ table: String) -> Bool {
        cursor(for: table) == nil
    }

    // MARK: Push

    func push() async throws {
        try await pushTombstones()
        try await pushRows(Friend.self, table: "friends") { friend in
            SyncFriendRow(id: friend.remoteID!, owner_id: ownerID, name: friend.name, connection_id: friend.connectionID, icon_name: friend.iconName)
        }
        try await pushRows(ExpenseGroup.self, table: "expense_groups") { group in
            GroupRow(id: group.remoteID!, owner_id: ownerID, name: group.name)
        }
        try await pushRows(Budget.self, table: "budgets") { (budget: Budget) -> BudgetRow? in
            guard let groupID = Self.reference(budget.group) else { return nil }
            return BudgetRow(id: budget.remoteID!, owner_id: ownerID, group_id: groupID, amount: budget.amount, period: budget.period.rawValue)
        }
        try await pushRows(Expense.self, table: "personal_expenses") { (expense: Expense) -> PersonalExpenseRow? in
            guard let groupID = Self.reference(expense.group), let friendID = Self.reference(expense.friend) else { return nil }
            return PersonalExpenseRow(
                id: expense.remoteID!, owner_id: ownerID, group_id: groupID, friend_id: friendID,
                title: expense.title, amount: expense.amount, comment: expense.comment, date: expense.date,
                paid_by_me: expense.paidByMe, split_type: expense.splitType.rawValue, is_settled: expense.isSettled
            )
        }
        try await pushRows(Activity.self, table: "personal_activities") { (activity: Activity) -> PersonalActivityRow? in
            guard let friendID = Self.reference(activity.friend) else { return nil }
            return PersonalActivityRow(
                id: activity.remoteID!, owner_id: ownerID, friend_id: friendID, friend_name: activity.friendName,
                type: activity.type.rawValue, expense_title: activity.expenseTitle, amount: activity.amount,
                paid_by_me: activity.paidByMe, date: activity.date
            )
        }
    }

    /// The remoteID to send for an optional relationship: `.some(nil)` when there is none,
    /// nil when the related row has no remoteID yet (skip the row until it has one, or the
    /// server's foreign key rejects the batch).
    private static func reference(_ model: (some SyncedModel)?) -> UUID?? {
        guard let model else { return .some(nil) }
        guard let remoteID = model.remoteID else { return nil }
        return .some(remoteID)
    }

    private func pushRows<M: SyncedModel, Row: Encodable>(_ type: M.Type, table: String, row: (M) -> Row?) async throws {
        let firstSync = isFirstSync(table)
        let models = try context.fetch(FetchDescriptor<M>()).filter {
            $0.syncTable == table && ($0.isDirty || firstSync)
        }
        guard !models.isEmpty else { return }
        SyncChangeTracker.applyingSyncChanges(in: context) {
            for model in models where model.remoteID == nil {
                model.remoteID = UUID()
            }
        }
        var pushed: [M] = []
        var rows: [Row] = []
        for model in models {
            if let built = row(model) {
                pushed.append(model)
                rows.append(built)
            }
        }
        try await backend.upsert(rows, into: table)
        SyncChangeTracker.applyingSyncChanges(in: context) {
            for model in pushed {
                model.isDirty = false
            }
        }
        // Tables pulled elsewhere (friends) never get a cursor from pull(), so mark the
        // one-time full upload as done here.
        if firstSync && !Self.pulledTables.contains(table) {
            setCursor(Date(), for: table)
        }
    }

    private func pushTombstones() async throws {
        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        guard !tombstones.isEmpty else { return }
        let byTable = Dictionary(grouping: tombstones, by: \.table)
        for (table, group) in byTable where Self.pushOrder.contains(table) {
            try await backend.markDeleted(group.map(\.remoteID), in: table)
        }
        // Shared-table tombstones are dropped: those deletes already went out as hard deletes.
        SyncChangeTracker.applyingSyncChanges(in: context) {
            for tombstone in tombstones {
                context.delete(tombstone)
            }
        }
    }

    // MARK: Pull

    func pull() async throws {
        let friends = try context.fetch(FetchDescriptor<Friend>())
        let friendsByID = Dictionary(friends.compactMap { f in f.remoteID.map { ($0, f) } }, uniquingKeysWith: { a, _ in a })

        try await pullRows(GroupRow.self, ExpenseGroup.self, table: "expense_groups") { row, local in
            let group = local ?? ExpenseGroup(name: row.name)
            group.name = row.name
            return group
        }

        let groups = try context.fetch(FetchDescriptor<ExpenseGroup>())
        let groupsByID = Dictionary(groups.compactMap { g in g.remoteID.map { ($0, g) } }, uniquingKeysWith: { a, _ in a })

        try await pullRows(BudgetRow.self, Budget.self, table: "budgets") { row, local in
            let period = BudgetPeriod(rawValue: row.period) ?? .week
            let budget = local ?? Budget(amount: row.amount, period: period)
            budget.amount = row.amount
            budget.period = period
            budget.group = row.group_id.flatMap { groupsByID[$0] }
            return budget
        }

        try await pullRows(PersonalExpenseRow.self, Expense.self, table: "personal_expenses") { row, local in
            let friend = row.friend_id.flatMap { friendsByID[$0] }
            // Once the friend is linked, the shared `expenses` table owns this expense.
            if friend?.linkedUserID != nil { return nil }
            let expense = local ?? Expense(title: row.title, amount: row.amount)
            expense.title = row.title
            expense.amount = row.amount
            expense.comment = row.comment
            expense.date = row.date
            expense.friend = friend
            expense.group = row.group_id.flatMap { groupsByID[$0] }
            expense.paidByMe = row.paid_by_me
            expense.splitType = SplitType(rawValue: row.split_type) ?? .equally
            expense.isSettled = row.is_settled
            return expense
        }

        try await pullRows(PersonalActivityRow.self, Activity.self, table: "personal_activities") { row, local in
            let friend = row.friend_id.flatMap { friendsByID[$0] }
            if friend?.linkedUserID != nil { return nil }
            let type = ActivityType(rawValue: row.type) ?? .created
            let activity = local ?? Activity(type: type, expenseTitle: row.expense_title, amount: row.amount, paidByMe: row.paid_by_me)
            activity.type = type
            activity.expenseTitle = row.expense_title
            activity.friendName = row.friend_name
            activity.amount = row.amount
            activity.paidByMe = row.paid_by_me
            activity.date = row.date
            activity.friend = friend
            return activity
        }
    }

    /// Applies changed rows: tombstones delete, rows with unpushed local edits are left for
    /// the next push (local wins), everything else is inserted or updated by remoteID.
    /// `apply` returns nil to skip a row.
    private func pullRows<Row: OwnerRow, M: SyncedModel>(_ rowType: Row.Type, _ modelType: M.Type, table: String, apply: (Row, M?) -> M?) async throws {
        let since = cursor(for: table).map { $0.addingTimeInterval(-Self.cursorOverlap) }
        let rows: [Row] = try await backend.fetchChanged(table, since: since)
        let locals = try context.fetch(FetchDescriptor<M>())
        var byRemoteID = Dictionary(locals.compactMap { m in m.remoteID.map { ($0, m) } }, uniquingKeysWith: { a, _ in a })

        SyncChangeTracker.applyingSyncChanges(in: context) {
            for row in rows {
                let local = byRemoteID[row.id]
                if row.deleted_at != nil {
                    if let local {
                        context.delete(local)
                        byRemoteID[row.id] = nil
                    }
                    continue
                }
                if let local, local.isDirty || local.syncTable != table {
                    continue
                }
                guard let model = apply(row, local) else { continue }
                if local == nil {
                    model.remoteID = row.id
                    context.insert(model)
                    byRemoteID[row.id] = model
                }
            }
        }
        if let latest = rows.compactMap(\.updated_at).max() {
            setCursor(latest, for: table)
        } else if cursor(for: table) == nil {
            setCursor(Date(timeIntervalSince1970: 0), for: table)
        }
    }
}
