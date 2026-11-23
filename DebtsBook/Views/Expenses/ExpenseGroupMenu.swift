import SwiftUI
import SwiftData

/// Sets an expense's group straight from a list, without the edit form. On a linked
/// friend's expense, any pick (None included) is a decision: it leaves "To categorize".
@MainActor
func assignGroup(_ group: ExpenseGroup?, to expense: Expense, in context: ModelContext) {
    expense.group = group
    if expense.friend?.linkedUserID != nil {
        expense.groupDecided = true
        expense.groupNeedsSync = true
    }
    DataStore.commit(context)
}

/// The groups as menu choices, checked on the expense's current one.
struct ExpenseGroupChoices: View {

    let expense: Expense
    let groups: [ExpenseGroup]

    @Environment(\.modelContext) private var modelContext

    private var selection: Binding<PersistentIdentifier?> {
        Binding {
            expense.group?.persistentModelID
        } set: { id in
            assignGroup(groups.first { $0.persistentModelID == id }, to: expense, in: modelContext)
        }
    }

    var body: some View {
        Picker("Group", selection: selection) {
            Text("None").tag(nil as PersistentIdentifier?)
            ForEach(groups) { group in
                Text(group.name)
                    .tag(group.persistentModelID as PersistentIdentifier?)
            }
        }
    }
}

/// Group chip under an expense row: tap opens the groups and applies the pick at once.
/// Hidden when there are no groups, or none of a shared expense is your spending.
struct ExpenseGroupMenu: View {

    let expense: Expense

    @Query(sort: \ExpenseGroup.name) private var groups: [ExpenseGroup]

    var body: some View {
        if !groups.isEmpty && expense.myShare > 0 {
            Menu {
                ExpenseGroupChoices(expense: expense, groups: groups)
            } label: {
                chip
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Group: \(expense.group?.name ?? "None")")
        }
    }

    private var chip: some View {
        HStack(spacing: 6) {
            if let group = expense.group {
                GroupIcon(group: group, size: 20)
                Text(group.name)
            } else {
                Image(systemName: "folder.badge.plus")
                Text("Add group")
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
