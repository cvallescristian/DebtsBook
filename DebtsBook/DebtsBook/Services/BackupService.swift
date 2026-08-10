import Foundation
import SwiftData

private struct BackupFriend: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
}

private struct BackupGroup: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
}

private struct BackupBudget: Codable {
    let amount: Decimal
    let period: String
    let groupID: UUID?
}

private struct BackupExpense: Codable {
    let id: UUID
    let title: String
    let amount: Decimal
    let isSettled: Bool
    let createdAt: Date
    let date: Date
    let friendID: UUID?
    let groupID: UUID?
    let paidByMe: Bool
    let splitType: String
    let comment: String?
}

private struct BackupActivity: Codable {
    let type: String
    let expenseTitle: String
    let friendName: String?
    let amount: Decimal
    let paidByMe: Bool
    let date: Date
    let expenseID: UUID?
    let friendID: UUID?
}

private struct BackupBundle: Codable {
    let version: Int
    let exportedAt: Date
    let friends: [BackupFriend]
    let groups: [BackupGroup]
    let budgets: [BackupBudget]
    let expenses: [BackupExpense]
    let activities: [BackupActivity]
}

enum BackupService {

    /// Exports every local record (friends, groups, budgets, expenses, activity) to a JSON
    /// file. Sync-specific fields (remoteID, linkedUserID, connectionID) are intentionally
    /// left out — an import starts those records as local-only until re-synced.
    static func exportData(context: ModelContext) throws -> URL {
        let friends = try context.fetch(FetchDescriptor<Friend>())
        let groups = try context.fetch(FetchDescriptor<ExpenseGroup>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let activities = try context.fetch(FetchDescriptor<Activity>())

        let friendIDs = Dictionary(uniqueKeysWithValues: friends.map { (ObjectIdentifier($0), UUID()) })
        let groupIDs = Dictionary(uniqueKeysWithValues: groups.map { (ObjectIdentifier($0), UUID()) })
        let expenseIDs = Dictionary(uniqueKeysWithValues: expenses.map { (ObjectIdentifier($0), UUID()) })

        let backupFriends = friends.map { friend in
            BackupFriend(id: friendIDs[ObjectIdentifier(friend)]!, name: friend.name, createdAt: friend.createdAt)
        }
        let backupGroups = groups.map { group in
            BackupGroup(id: groupIDs[ObjectIdentifier(group)]!, name: group.name, createdAt: group.createdAt)
        }
        let backupBudgets = budgets.map { budget in
            BackupBudget(
                amount: budget.amount,
                period: budget.period.rawValue,
                groupID: budget.group.flatMap { groupIDs[ObjectIdentifier($0)] }
            )
        }
        let backupExpenses = expenses.map { expense in
            BackupExpense(
                id: expenseIDs[ObjectIdentifier(expense)]!,
                title: expense.title,
                amount: expense.amount,
                isSettled: expense.isSettled,
                createdAt: expense.createdAt,
                date: expense.date,
                friendID: expense.friend.flatMap { friendIDs[ObjectIdentifier($0)] },
                groupID: expense.group.flatMap { groupIDs[ObjectIdentifier($0)] },
                paidByMe: expense.paidByMe,
                splitType: expense.splitType.rawValue,
                comment: expense.comment
            )
        }
        let backupActivities = activities.map { activity in
            BackupActivity(
                type: activity.type.rawValue,
                expenseTitle: activity.expenseTitle,
                friendName: activity.friendName,
                amount: activity.amount,
                paidByMe: activity.paidByMe,
                date: activity.date,
                expenseID: activity.expense.flatMap { expenseIDs[ObjectIdentifier($0)] },
                friendID: activity.friend.flatMap { friendIDs[ObjectIdentifier($0)] }
            )
        }

        let bundle = BackupBundle(
            version: 1,
            exportedAt: Date(),
            friends: backupFriends,
            groups: backupGroups,
            budgets: backupBudgets,
            expenses: backupExpenses,
            activities: backupActivities
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "DebtsBook-Backup-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Imports records from a previously exported JSON file, adding them as new local
    /// records alongside whatever's already in the store.
    static func importData(from url: URL, into context: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(BackupBundle.self, from: data)

        var friendsByID: [UUID: Friend] = [:]
        var groupsByID: [UUID: ExpenseGroup] = [:]
        var expensesByID: [UUID: Expense] = [:]

        for backupFriend in bundle.friends {
            let friend = Friend(name: backupFriend.name)
            friend.createdAt = backupFriend.createdAt
            context.insert(friend)
            friendsByID[backupFriend.id] = friend
        }

        for backupGroup in bundle.groups {
            let group = ExpenseGroup(name: backupGroup.name)
            group.createdAt = backupGroup.createdAt
            context.insert(group)
            groupsByID[backupGroup.id] = group
        }

        for backupBudget in bundle.budgets {
            let period = BudgetPeriod(rawValue: backupBudget.period) ?? .week
            let group = backupBudget.groupID.flatMap { groupsByID[$0] }
            context.insert(Budget(amount: backupBudget.amount, period: period, group: group))
        }

        for backupExpense in bundle.expenses {
            let friend = backupExpense.friendID.flatMap { friendsByID[$0] }
            let group = backupExpense.groupID.flatMap { groupsByID[$0] }
            let splitType = SplitType(rawValue: backupExpense.splitType) ?? .equally
            let expense = Expense(
                title: backupExpense.title,
                amount: backupExpense.amount,
                friend: friend,
                group: group,
                paidByMe: backupExpense.paidByMe,
                splitType: splitType,
                date: backupExpense.date,
                comment: backupExpense.comment
            )
            expense.isSettled = backupExpense.isSettled
            expense.createdAt = backupExpense.createdAt
            context.insert(expense)
            expensesByID[backupExpense.id] = expense
        }

        for backupActivity in bundle.activities {
            let type = ActivityType(rawValue: backupActivity.type) ?? .created
            let expense = backupActivity.expenseID.flatMap { expensesByID[$0] }
            let friend = backupActivity.friendID.flatMap { friendsByID[$0] }
            context.insert(Activity(
                type: type,
                expenseTitle: backupActivity.expenseTitle,
                friendName: backupActivity.friendName,
                amount: backupActivity.amount,
                paidByMe: backupActivity.paidByMe,
                expense: expense,
                friend: friend,
                date: backupActivity.date
            ))
        }
    }
}
