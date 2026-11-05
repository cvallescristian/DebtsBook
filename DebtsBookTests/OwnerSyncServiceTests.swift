import Testing
import Foundation
import SwiftData
@testable import DebtsBook

/// In-memory stand-in for the owner-only Supabase tables: stores rows as JSON objects and,
/// like the set_updated_at trigger, stamps updated_at on every write.
private final class FakeSyncBackend: SyncBackend {
    var tables: [String: [UUID: [String: Any]]] = [:]
    /// Rows the "server" refuses (like a foreign key violation), failing any batch containing them.
    var rejectedIDs: Set<UUID> = []

    struct Rejected: Error {}
    var isOffline = false
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func tick() -> String {
        clock = clock.addingTimeInterval(1)
        return clock.ISO8601Format()
    }

    func row(_ table: String, _ id: UUID) -> [String: Any]? {
        tables[table]?[id]
    }

    func upsert<Row: Encodable>(_ rows: [Row], into table: String) async throws {
        if isOffline {
            throw URLError(.notConnectedToInternet)
        }
        let objects = try rows.map { try JSONSerialization.jsonObject(with: encoder.encode($0)) as! [String: Any] }
        if objects.contains(where: { rejectedIDs.contains(UUID(uuidString: $0["id"] as! String)!) }) {
            throw Rejected()
        }
        for row in rows {
            var object = try JSONSerialization.jsonObject(with: encoder.encode(row)) as! [String: Any]
            let id = UUID(uuidString: object["id"] as! String)!
            object = (tables[table]?[id] ?? [:]).merging(object) { _, new in new }
            object["updated_at"] = tick()
            tables[table, default: [:]][id] = object
        }
    }

    func markDeleted(_ ids: [UUID], in table: String) async throws {
        for id in ids where tables[table]?[id] != nil {
            let now = tick()
            tables[table]?[id]?["deleted_at"] = now
            tables[table]?[id]?["updated_at"] = now
        }
    }

    func fetchChanged<Row: Decodable>(_ table: String, since: Date?) async throws -> [Row] {
        let rows = (tables[table] ?? [:]).values.filter { object in
            guard let since else { return true }
            let updated = ISO8601DateFormatter().date(from: object["updated_at"] as! String)!
            return updated > since
        }
        let data = try JSONSerialization.data(withJSONObject: Array(rows))
        return try decoder.decode([Row].self, from: data)
    }

    /// Simulates a write from another of the owner's devices.
    func insertRemote(_ table: String, _ object: [String: Any]) {
        var object = object
        object["updated_at"] = tick()
        tables[table, default: [:]][UUID(uuidString: object["id"] as! String)!] = object
    }
}

@MainActor
struct OwnerSyncServiceTests {

    private let backend = FakeSyncBackend()
    private let ownerID = UUID()
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeContext() throws -> ModelContext {
        let context = TestModelContainer.shared.mainContext
        SyncChangeTracker.start(observing: context)
        AccountOwnership.eraseLocalData(in: context)
        try context.save()
        return context
    }

    private func makeService(_ context: ModelContext) -> OwnerSyncService {
        OwnerSyncService(backend: backend, context: context, ownerID: ownerID, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func pushesPersonalExpenseWithItsReferencesAndClearsDirty() async throws {
        let context = try makeContext()
        let food = ExpenseGroup(name: "Food")
        let sam = Friend(name: "Sam")
        let lunch = Expense(title: "Lunch", amount: Decimal(string: "12.50")!, friend: sam, group: food, paidByMe: false, date: date)
        context.insert(food)
        context.insert(sam)
        context.insert(lunch)
        try context.save()

        try await makeService(context).push()

        let lunchID = try #require(lunch.remoteID)
        let samID = try #require(sam.remoteID)
        let row = try #require(backend.row("personal_expenses", lunchID))
        #expect(row["title"] as? String == "Lunch")
        #expect(row["group_id"] as? String == food.remoteID?.uuidString)
        #expect(row["friend_id"] as? String == sam.remoteID?.uuidString)
        #expect(row["paid_by_me"] as? Bool == false)
        #expect(backend.row("friends", samID) != nil)
        #expect(!lunch.isDirty && !food.isDirty && !sam.isDirty)
    }

    /// A phone coming from build 1.1: old rows were never marked dirty and (except friends)
    /// have no remoteID. Even if the first upload fails and a pull runs in between, the next
    /// sync must upload all of it.
    @Test func upgradeFromOldBuildUploadsEverythingEvenAfterAFailedFirstAttempt() async throws {
        let context = try makeContext()
        let ana = Friend(name: "Ana")
        ana.remoteID = UUID()
        let food = ExpenseGroup(name: "Food")
        let budget = Budget(amount: 100, period: .week, group: food)
        let lunch = Expense(title: "Lunch", amount: 12, group: food, date: date)
        let dinner = Expense(title: "Dinner", amount: 30, friend: ana, date: date)
        let activity = Activity(type: .created, expenseTitle: "Lunch", amount: 12, paidByMe: true, date: date)
        SyncChangeTracker.applyingSyncChanges(in: context) {
            for model in [ana, food, budget, lunch, dinner, activity] as [any PersistentModel] {
                context.insert(model)
            }
        }
        let service = makeService(context)

        backend.isOffline = true
        try? await service.push()
        backend.isOffline = false
        try await service.pull()
        try await service.sync()

        let uploaded: [(String, any SyncedModel)] = [
            ("friends", ana), ("expense_groups", food), ("budgets", budget),
            ("personal_expenses", lunch), ("personal_expenses", dinner), ("personal_activities", activity),
        ]
        for (table, model) in uploaded {
            let remoteID = try #require(model.remoteID)
            #expect(backend.row(table, remoteID) != nil, "\(table) row missing")
            #expect(model.isSynced)
        }
    }

    @Test func aRejectedRowDoesNotBlockTheRest() async throws {
        let context = try makeContext()
        let good = ExpenseGroup(name: "Food")
        let bad = ExpenseGroup(name: "Broken")
        context.insert(good)
        context.insert(bad)
        try context.save()
        backend.rejectedIDs = [try #require(bad.remoteID)]

        try await makeService(context).push()

        let goodID = try #require(good.remoteID)
        #expect(backend.row("expense_groups", goodID) != nil)
        #expect(!good.isDirty)
        #expect(bad.isDirty)
    }

    @Test func friendUploadLeavesLinksToTheInviteFlow() async throws {
        let context = try makeContext()
        let sam = Friend(name: "Sam")
        sam.connectionID = UUID()
        context.insert(sam)
        try context.save()

        try await makeService(context).push()

        let samID = try #require(sam.remoteID)
        let row = try #require(backend.row("friends", samID))
        #expect(row["connection_id"] == nil)
    }

    @Test func clearingAReferenceSendsAnExplicitNull() async throws {
        let context = try makeContext()
        let food = ExpenseGroup(name: "Food")
        let lunch = Expense(title: "Lunch", amount: 12, group: food, date: date)
        context.insert(food)
        context.insert(lunch)
        try context.save()
        let service = makeService(context)
        try await service.push()

        lunch.group = nil
        try context.save()
        try await service.push()

        let lunchID = try #require(lunch.remoteID)
        let row = try #require(backend.row("personal_expenses", lunchID))
        #expect(row["group_id"] is NSNull)
    }

    @Test func deletingPushesATombstoneAndDropsIt() async throws {
        let context = try makeContext()
        let budget = Budget(amount: 100, period: .week)
        context.insert(budget)
        try context.save()
        let service = makeService(context)
        try await service.push()
        let remoteID = try #require(budget.remoteID)

        context.delete(budget)
        try context.save()
        try await service.push()

        #expect(backend.row("budgets", remoteID)?["deleted_at"] is String)
        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).isEmpty)
    }

    @Test func firstSyncUploadsRowsThatWereNeverMarkedDirty() async throws {
        let context = try makeContext()
        let group = ExpenseGroup(name: "Travel")
        SyncChangeTracker.applyingSyncChanges(in: context) { context.insert(group) }
        #expect(!group.isDirty)

        try await makeService(context).sync()

        let remoteID = try #require(group.remoteID)
        #expect(backend.row("expense_groups", remoteID)?["name"] as? String == "Travel")
    }

    @Test func pullInsertsUpdatesAndDeletesFromOtherDevices() async throws {
        let context = try makeContext()
        let service = makeService(context)
        try await service.sync()

        let groupID = UUID()
        backend.insertRemote("expense_groups", ["id": groupID.uuidString, "name": "Food"])
        let budgetID = UUID()
        backend.insertRemote("budgets", ["id": budgetID.uuidString, "group_id": groupID.uuidString, "amount": 200, "period": "Month"])
        try await service.pull()

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first { $0.remoteID == budgetID })
        #expect(budget.amount == 200 && budget.period == .month)
        #expect(budget.group?.name == "Food")
        #expect(!budget.isDirty)

        try await backend.markDeleted([budgetID], in: "budgets")
        try await service.pull()

        #expect(try context.fetch(FetchDescriptor<Budget>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).isEmpty)
    }

    @Test func pullKeepsUnpushedLocalEdits() async throws {
        let context = try makeContext()
        let group = ExpenseGroup(name: "Food")
        context.insert(group)
        try context.save()
        let service = makeService(context)
        try await service.sync()
        let remoteID = try #require(group.remoteID)

        backend.insertRemote("expense_groups", ["id": remoteID.uuidString, "name": "Remote name"])
        group.name = "Local name"
        try context.save()
        try await service.pull()

        #expect(group.name == "Local name")
        #expect(group.isDirty)
    }

    @Test func pullSkipsExpensesOfALinkedFriend() async throws {
        let context = try makeContext()
        let sam = Friend(name: "Sam")
        context.insert(sam)
        try context.save()
        let service = makeService(context)
        try await service.sync()
        sam.linkedUserID = UUID()
        try context.save()

        let samID = try #require(sam.remoteID)
        backend.insertRemote("personal_expenses", [
            "id": UUID().uuidString, "friend_id": samID.uuidString, "title": "Dinner",
            "amount": 30, "date": date.ISO8601Format(), "paid_by_me": true, "split_type": "equally", "is_settled": false,
        ])
        try await service.pull()

        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
    }
}
