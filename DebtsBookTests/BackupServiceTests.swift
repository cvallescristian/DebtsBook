import Testing
import Foundation
import SwiftData
@testable import DebtsBook

/// Export → import must keep working as the models evolve. The coverage guard fails whenever
/// a model or stored property is added, so each new field gets an explicit backup decision.
@MainActor
struct BackupServiceTests {

    /// Fields included in a backup, per model.
    private static let backedUp: [String: Set<String>] = [
        "Friend": ["name", "createdAt", "photoData", "iconName"],
        "ExpenseGroup": ["name", "createdAt"],
        "Budget": ["amount", "period", "group"],
        "Expense": ["title", "amount", "isSettled", "createdAt", "date", "friend", "group", "paidByMe", "splitType", "comment"],
        "Activity": ["type", "expenseTitle", "friendName", "amount", "paidByMe", "performedByMe", "date", "expense", "friend"],
    ]

    /// Fields deliberately left out: sync state is rebuilt on re-link, and pending Apple Pay
    /// payments are short-lived, device-only drafts.
    private static let notBackedUp: [String: Set<String>] = [
        "Friend": ["remoteID", "linkedUserID", "connectionID", "lastSyncedAt", "isDirty"],
        "Expense": ["remoteID", "isDirty"],
        "Activity": ["remoteID", "isDirty"],
        "ExpenseGroup": ["remoteID", "isDirty"],
        "Budget": ["remoteID", "isDirty"],
        "SyncTombstone": ["table", "remoteID", "date"],
        "PendingExpense": ["merchant", "amount", "cardName", "date"],
    ]

    private func makeContext() throws -> ModelContext {
        let context = TestModelContainer.shared.mainContext
        try wipe(context)
        return context
    }

    private func wipe(_ context: ModelContext) throws {
        for model in AppModelContainer.modelTypes {
            try deleteAll(model, in: context)
        }
        try context.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }

    private func roundTrip(_ context: ModelContext) throws {
        try context.save()
        let url = try BackupService.exportData(context: context)
        defer { try? FileManager.default.removeItem(at: url) }
        try wipe(context)
        try BackupService.importData(from: url, into: context)
        try context.save()
    }

    @Test func everyModelFieldHasABackupDecision() {
        let schema = Schema(AppModelContainer.modelTypes)
        for entity in schema.entities {
            let actual = Set(entity.properties.map(\.name))
            let decided = (Self.backedUp[entity.name] ?? []).union(Self.notBackedUp[entity.name] ?? [])
            #expect(actual == decided, "\(entity.name): decide whether \(actual.subtracting(decided).sorted()) belong in backups (BackupService + this test)")
        }
    }

    @Test func roundTripKeepsEveryBackedUpField() throws {
        let context = try makeContext()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let ana = Friend(name: "Ana")
        ana.createdAt = date
        ana.photoData = Data([1, 2, 3])
        ana.iconName = "star"
        let exportedRemoteID = UUID()
        ana.remoteID = exportedRemoteID
        context.insert(ana)

        let food = ExpenseGroup(name: "Food")
        food.createdAt = date
        context.insert(food)

        context.insert(Budget(amount: 200, period: .month, group: food))

        let dinner = Expense(title: "Dinner", amount: Decimal(string: "61.50")!, friend: ana, paidByMe: false, splitType: .fullAmount, date: date, comment: "Birthday")
        dinner.isSettled = true
        dinner.createdAt = date
        context.insert(dinner)

        let groceries = Expense(title: "Groceries", amount: 40, group: food, date: date)
        context.insert(groceries)

        context.insert(Activity(type: .paid, expenseTitle: "Dinner", friendName: "Ana", amount: Decimal(string: "61.50")!, paidByMe: false, performedByMe: false, expense: dinner, friend: ana, date: date))
        context.insert(PendingExpense(merchant: "Countdown", amount: 12))

        try roundTrip(context)

        let friend = try #require(try context.fetch(FetchDescriptor<Friend>()).only)
        #expect(friend.name == "Ana")
        #expect(friend.createdAt == date)
        #expect(friend.photoData == Data([1, 2, 3]))
        #expect(friend.iconName == "star")
        // Sync links aren't imported; SyncChangeTracker may give the new row a fresh ID.
        #expect(friend.remoteID != exportedRemoteID)

        let group = try #require(try context.fetch(FetchDescriptor<ExpenseGroup>()).only)
        #expect(group.name == "Food")
        #expect(group.createdAt == date)

        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).only)
        #expect(budget.amount == 200)
        #expect(budget.period == .month)
        #expect(budget.group === group)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        #expect(expenses.count == 2)
        let restoredDinner = try #require(expenses.first { $0.title == "Dinner" })
        #expect(restoredDinner.amount == Decimal(string: "61.50"))
        #expect(restoredDinner.isSettled)
        #expect(restoredDinner.createdAt == date)
        #expect(restoredDinner.date == date)
        #expect(restoredDinner.friend === friend)
        #expect(!restoredDinner.paidByMe)
        #expect(restoredDinner.splitType == .fullAmount)
        #expect(restoredDinner.comment == "Birthday")
        let restoredGroceries = try #require(expenses.first { $0.title == "Groceries" })
        #expect(restoredGroceries.group === group)
        #expect(restoredGroceries.isPersonal)

        let activity = try #require(try context.fetch(FetchDescriptor<Activity>()).only)
        #expect(activity.type == .paid)
        #expect(activity.expenseTitle == "Dinner")
        #expect(activity.friendName == "Ana")
        #expect(activity.amount == Decimal(string: "61.50"))
        #expect(!activity.paidByMe)
        #expect(!activity.performedByMe)
        #expect(activity.date == date)
        #expect(activity.expense === restoredDinner)
        #expect(activity.friend === friend)

        #expect(try context.fetchCount(FetchDescriptor<PendingExpense>()) == 0)
    }

    @Test func importsVersionOneBackup() throws {
        let context = try makeContext()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-v1-\(UUID()).json")
        try Data(Self.versionOneBackup.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try BackupService.importData(from: url, into: context)
        try context.save()

        let friend = try #require(try context.fetch(FetchDescriptor<Friend>()).only)
        #expect(friend.name == "Ana")
        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).only)
        #expect(budget.period == .week)
        #expect(budget.group?.name == "Food")
        let expense = try #require(try context.fetch(FetchDescriptor<Expense>()).only)
        #expect(expense.title == "Dinner")
        #expect(expense.amount == 30)
        #expect(expense.friend === friend)
        let activity = try #require(try context.fetch(FetchDescriptor<Activity>()).only)
        // performedByMe didn't exist in the earliest exports; it defaults to true.
        #expect(activity.performedByMe)
        #expect(activity.expense === expense)
    }

    /// A backup exactly as the first released export wrote it. Never edit: it stands in for
    /// files users already have.
    private static let versionOneBackup = """
    {
      "activities" : [
        {
          "amount" : 15,
          "date" : "2026-01-10T09:00:00Z",
          "expenseID" : "33333333-3333-3333-3333-333333333333",
          "expenseTitle" : "Dinner",
          "friendID" : "11111111-1111-1111-1111-111111111111",
          "friendName" : "Ana",
          "paidByMe" : true,
          "type" : "created"
        }
      ],
      "budgets" : [
        {
          "amount" : 100,
          "groupID" : "22222222-2222-2222-2222-222222222222",
          "period" : "Week"
        }
      ],
      "expenses" : [
        {
          "amount" : 30,
          "createdAt" : "2026-01-10T09:00:00Z",
          "date" : "2026-01-10T09:00:00Z",
          "friendID" : "11111111-1111-1111-1111-111111111111",
          "id" : "33333333-3333-3333-3333-333333333333",
          "isSettled" : false,
          "paidByMe" : true,
          "splitType" : "equally",
          "title" : "Dinner"
        }
      ],
      "exportedAt" : "2026-01-10T10:00:00Z",
      "friends" : [
        {
          "createdAt" : "2026-01-01T00:00:00Z",
          "id" : "11111111-1111-1111-1111-111111111111",
          "name" : "Ana"
        }
      ],
      "groups" : [
        {
          "createdAt" : "2026-01-01T00:00:00Z",
          "id" : "22222222-2222-2222-2222-222222222222",
          "name" : "Food"
        }
      ],
      "version" : 1
    }
    """
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
