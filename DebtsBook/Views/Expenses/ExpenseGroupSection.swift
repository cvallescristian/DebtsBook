import SwiftUI
import SwiftData

/// Group picker for the expense forms. On a shared expense, picking a group is what counts
/// your share as spending in Reports, so the footer spells that out.
struct ExpenseGroupSection: View {

    let groups: [ExpenseGroup]
    @Binding var groupID: PersistentIdentifier?
    /// Your share of a shared expense; nil for personal expenses.
    let sharedShare: Decimal?

    var body: some View {
        Section {
            Picker("Group", selection: $groupID) {
                Text("None").tag(nil as PersistentIdentifier?)
                ForEach(groups) { group in
                    Text(group.name)
                        .tag(group.persistentModelID as PersistentIdentifier?)
                }
            }
        } header: {
            Text("Group")
        } footer: {
            footer
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let sharedShare {
            if groupID == nil {
                Text("Pick a group to count your share in Reports.")
            } else if sharedShare == 0 {
                Text("None of this is your spending, so it won't count in Reports.")
            } else {
                Text("Your share of \(sharedShare.formatted(.currency(code: "NZD"))) counts in Reports.")
            }
        }
    }
}
