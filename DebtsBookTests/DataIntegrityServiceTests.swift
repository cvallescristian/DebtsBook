import Testing
import Foundation
import SwiftData
@testable import DebtsBook

@MainActor
struct DataIntegrityServiceTests {

    /// Reuses the single shared container (see TestSupport.swift) instead of creating a new
    /// one per test — SwiftData traps if two containers for the same @Model types are alive
    /// in the same process, which the hosted test bundle otherwise triggers immediately.
    private func makeContext() throws -> ModelContext {
        TestModelContainer.shared.mainContext
    }

    @Test func clearsDanglingExpenseFriendReference() throws {
        let context = try makeContext()
        let friend = Friend(name: "Ana")
        context.insert(friend)
        let expense = Expense(title: "Dinner", amount: 20, friend: friend)
        context.insert(expense)
        try context.save()

        context.delete(friend)
        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(expense.friend == nil)
    }

    @Test func clearsDanglingExpenseGroupReference() throws {
        let context = try makeContext()
        let group = ExpenseGroup(name: "Food")
        context.insert(group)
        let expense = Expense(title: "Groceries", amount: 20, group: group)
        context.insert(expense)
        try context.save()

        context.delete(group)
        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(expense.group == nil)
    }

    @Test func clearsDanglingBudgetGroupReference() throws {
        let context = try makeContext()
        let group = ExpenseGroup(name: "Food")
        context.insert(group)
        let budget = Budget(amount: 100, period: .week, group: group)
        context.insert(budget)
        try context.save()

        context.delete(group)
        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(budget.group == nil)
    }

    @Test func clearsDanglingActivityExpenseReference() throws {
        let context = try makeContext()
        let expense = Expense(title: "Coffee", amount: 5)
        context.insert(expense)
        let activity = Activity(type: .created, expenseTitle: "Coffee", amount: 5, paidByMe: true, expense: expense)
        context.insert(activity)
        try context.save()

        context.delete(expense)
        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(activity.expense == nil)
    }

    /// The disconnect/reconnect data-loss bug: a friend left half-disconnected (no active
    /// connection, but still flagged as linked, with stale remoteIDs from before disconnect
    /// started clearing them) should be fully reconciled — matching what a normal disconnect
    /// does now — so a future reconnect treats the history as unsynced instead of reusing
    /// dead remote IDs.
    @Test func healsHalfDisconnectedFriendAndClearsStaleRemoteIDs() throws {
        let context = try makeContext()
        let friend = Friend(name: "Ana")
        friend.connectionID = nil
        friend.linkedUserID = UUID()
        context.insert(friend)

        let expense = Expense(title: "Dinner", amount: 20, friend: friend)
        expense.remoteID = UUID()
        context.insert(expense)

        let activity = Activity(type: .created, expenseTitle: "Dinner", amount: 20, paidByMe: true, friend: friend)
        activity.remoteID = UUID()
        context.insert(activity)

        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(friend.linkedUserID == nil)
        #expect(expense.remoteID == nil)
        #expect(activity.remoteID == nil)
    }

    @Test func leavesAGenuinelyConnectedFriendUntouched() throws {
        let context = try makeContext()
        let friend = Friend(name: "Ana")
        friend.connectionID = UUID()
        friend.linkedUserID = UUID()
        context.insert(friend)

        let expenseRemoteID = UUID()
        let expense = Expense(title: "Dinner", amount: 20, friend: friend)
        expense.remoteID = expenseRemoteID
        context.insert(expense)

        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(friend.linkedUserID != nil)
        #expect(expense.remoteID == expenseRemoteID)
    }

    @Test func leavesAnEverLocalFriendUntouched() throws {
        // Never invited/connected: connectionID and linkedUserID both nil from the start —
        // must not be mistaken for the half-disconnected state.
        let context = try makeContext()
        let friend = Friend(name: "Ana")
        context.insert(friend)
        try context.save()

        DataIntegrityService.repairDanglingRelationships(context: context)

        #expect(friend.connectionID == nil)
        #expect(friend.linkedUserID == nil)
    }
}
