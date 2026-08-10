import Foundation
import SwiftData

/// One-time repair pass run at launch, before any view can render and crash on it.
///
/// Expense.friend/group (and Budget.group) previously had no explicit @Relationship delete
/// rule, so some devices ended up with an Expense still pointing at a Friend/ExpenseGroup
/// that had already been deleted from the local store — reading any property through that
/// dangling reference (e.g. `friend.name`) crashes with "This model instance was invalidated
/// because its backing data could no longer be found in the store." The models now declare
/// an explicit `.nullify` rule so this can't happen again going forward, but that doesn't
/// retroactively repair data already saved with a dangling reference — hence this pass.
///
/// `persistentModelID` is identity metadata, not a regular stored property, so reading it
/// off a model whose backing row is gone does NOT trigger the same crash — that's what makes
/// this detection possible without touching the property that would actually blow up.
enum DataIntegrityService {

    static func repairDanglingRelationships(context: ModelContext) {
        let validFriendIDs = Set(((try? context.fetch(FetchDescriptor<Friend>())) ?? []).map(\.persistentModelID))
        let validGroupIDs = Set(((try? context.fetch(FetchDescriptor<ExpenseGroup>())) ?? []).map(\.persistentModelID))

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        for expense in expenses {
            if let friend = expense.friend, !validFriendIDs.contains(friend.persistentModelID) {
                expense.friend = nil
            }
            if let group = expense.group, !validGroupIDs.contains(group.persistentModelID) {
                expense.group = nil
            }
        }

        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        for budget in budgets {
            if let group = budget.group, !validGroupIDs.contains(group.persistentModelID) {
                budget.group = nil
            }
        }

        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let validExpenseIDs = Set(expenses.map(\.persistentModelID))
        for activity in activities {
            if let friend = activity.friend, !validFriendIDs.contains(friend.persistentModelID) {
                activity.friend = nil
            }
            if let expense = activity.expense, !validExpenseIDs.contains(expense.persistentModelID) {
                activity.expense = nil
            }
        }

        try? context.save()
    }
}
