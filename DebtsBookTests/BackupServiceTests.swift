import Testing
import Foundation
import SwiftData
@testable import DebtsBook

@MainActor
struct BackupServiceTests {

    private func makeContext() throws -> ModelContext {
        let container = TestModelContainer.shared
        let context = ModelContext(container)
        for friend in try context.fetch(FetchDescriptor<Friend>()) { context.delete(friend) }
        for group in try context.fetch(FetchDescriptor<ExpenseGroup>()) { context.delete(group) }
        for budget in try context.fetch(FetchDescriptor<Budget>()) { context.delete(budget) }
        for expense in try context.fetch(FetchDescriptor<Expense>()) { context.delete(expense) }
        for activity in try context.fetch(FetchDescriptor<Activity>()) { context.delete(activity) }
        try context.save()
        return context
    }

    @Test func exportThenImportRoundTripsAllRecordTypes() throws {
        let sourceContext = try makeContext()

        let friend = Friend(name: "Ana")
        friend.remoteID = UUID()
        friend.linkedUserID = UUID()
        sourceContext.insert(friend)

        let group = ExpenseGroup(name: "Food")
        sourceContext.insert(group)

        let budget = Budget(amount: 100, period: .month, group: group)
        sourceContext.insert(budget)

        let expense = Expense(title: "Dinner", amount: 30, friend: friend, group: group, paidByMe: true, splitType: .equally, comment: "split with Ana")
        expense.isSettled = true
        sourceContext.insert(expense)

        let activity = Activity(type: .created, expenseTitle: "Dinner", friendName: "Ana", amount: 15, paidByMe: true, expense: expense, friend: friend)
        sourceContext.insert(activity)

        try sourceContext.save()

        let url = try BackupService.exportData(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: url) }

        for f in try sourceContext.fetch(FetchDescriptor<Friend>()) { sourceContext.delete(f) }
        for g in try sourceContext.fetch(FetchDescriptor<ExpenseGroup>()) { sourceContext.delete(g) }
        for b in try sourceContext.fetch(FetchDescriptor<Budget>()) { sourceContext.delete(b) }
        for e in try sourceContext.fetch(FetchDescriptor<Expense>()) { sourceContext.delete(e) }
        for a in try sourceContext.fetch(FetchDescriptor<Activity>()) { sourceContext.delete(a) }
        try sourceContext.save()

        try BackupService.importData(from: url, into: sourceContext)
        try sourceContext.save()

        let importedFriends = try sourceContext.fetch(FetchDescriptor<Friend>())
        let importedGroups = try sourceContext.fetch(FetchDescriptor<ExpenseGroup>())
        let importedBudgets = try sourceContext.fetch(FetchDescriptor<Budget>())
        let importedExpenses = try sourceContext.fetch(FetchDescriptor<Expense>())
        let importedActivities = try sourceContext.fetch(FetchDescriptor<Activity>())

        #expect(importedFriends.count == 1)
        #expect(importedGroups.count == 1)
        #expect(importedBudgets.count == 1)
        #expect(importedExpenses.count == 1)
        #expect(importedActivities.count == 1)

        let importedFriend = try #require(importedFriends.first)
        #expect(importedFriend.name == "Ana")
        // Sync-specific fields are intentionally not exported, so the import must start
        // this friend as local-only rather than reusing the old sync identity.
        #expect(importedFriend.remoteID == nil)
        #expect(importedFriend.linkedUserID == nil)

        let importedExpense = try #require(importedExpenses.first)
        #expect(importedExpense.title == "Dinner")
        #expect(importedExpense.amount == 30)
        #expect(importedExpense.isSettled == true)
        #expect(importedExpense.comment == "split with Ana")
        #expect(importedExpense.friend?.name == "Ana")
        #expect(importedExpense.group?.name == "Food")

        let importedBudget = try #require(importedBudgets.first)
        #expect(importedBudget.amount == 100)
        #expect(importedBudget.period == .month)
        #expect(importedBudget.group?.name == "Food")

        let importedActivity = try #require(importedActivities.first)
        #expect(importedActivity.expenseTitle == "Dinner")
        #expect(importedActivity.friend?.name == "Ana")
        #expect(importedActivity.expense?.title == "Dinner")
    }

    @Test func importingTwiceAddsRecordsAlongsideExisting() throws {
        let context = try makeContext()
        let friend = Friend(name: "Ana")
        context.insert(friend)
        try context.save()

        let url = try BackupService.exportData(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        try BackupService.importData(from: url, into: context)
        try BackupService.importData(from: url, into: context)
        try context.save()

        let friends = try context.fetch(FetchDescriptor<Friend>())
        // Original + two imports of that one backed-up friend.
        #expect(friends.count == 3)
    }
}
