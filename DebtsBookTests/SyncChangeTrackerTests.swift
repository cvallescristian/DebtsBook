import Testing
import Foundation
import SwiftData
@testable import DebtsBook

@MainActor
struct SyncChangeTrackerTests {

    private func makeContext() throws -> ModelContext {
        let context = TestModelContainer.shared.mainContext
        SyncChangeTracker.start(observing: context)
        AccountOwnership.eraseLocalData(in: context)
        try context.save()
        return context
    }

    private func tombstones(in context: ModelContext) throws -> [SyncTombstone] {
        try context.fetch(FetchDescriptor<SyncTombstone>())
    }

    @Test func savingNewRowsMarksThemDirtyWithARemoteID() throws {
        let context = try makeContext()
        let group = ExpenseGroup(name: "Food")
        let lunch = Expense(title: "Lunch", amount: 12, group: group)
        context.insert(group)
        context.insert(lunch)
        try context.save()

        #expect(group.isDirty && group.remoteID != nil)
        #expect(lunch.isDirty && lunch.remoteID != nil)
        #expect(lunch.syncTable == "personal_expenses")
    }

    @Test func editingASyncedRowMarksItDirtyAgain() throws {
        let context = try makeContext()
        let budget = Budget(amount: 100, period: .week)
        context.insert(budget)
        try context.save()
        SyncChangeTracker.applyingSyncChanges(in: context) { budget.isDirty = false }

        budget.amount = 150
        try context.save()

        #expect(budget.isDirty)
    }

    @Test func syncWritesDoNotCountAsLocalEdits() throws {
        let context = try makeContext()
        let friend = Friend(name: "Sam")
        SyncChangeTracker.applyingSyncChanges(in: context) { context.insert(friend) }

        #expect(!friend.isDirty)
    }

    @Test func deletingASyncedRowLeavesATombstone() throws {
        let context = try makeContext()
        let friend = Friend(name: "Sam")
        context.insert(friend)
        try context.save()
        let remoteID = try #require(friend.remoteID)

        context.delete(friend)
        try context.save()

        let saved = try tombstones(in: context)
        #expect(saved.count == 1)
        #expect(saved.first?.table == "friends")
        #expect(saved.first?.remoteID == remoteID)
    }

    @Test func deletingANeverSyncedRowLeavesNoTombstone() throws {
        let context = try makeContext()
        let friend = Friend(name: "Sam")
        SyncChangeTracker.applyingSyncChanges(in: context) { context.insert(friend) }

        context.delete(friend)
        try context.save()

        #expect(try tombstones(in: context).isEmpty)
    }

    @Test func linkedFriendRowsKeepTheirIDsForTheSharedServices() throws {
        let context = try makeContext()
        let friend = Friend(name: "Sam")
        friend.linkedUserID = UUID()
        let dinner = Expense(title: "Dinner", amount: 30, friend: friend)
        context.insert(friend)
        context.insert(dinner)
        try context.save()

        #expect(dinner.syncTable == "expenses")
        #expect(dinner.isDirty && dinner.remoteID == nil)
    }
}
