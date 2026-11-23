import SwiftUI
import SwiftData

struct GroupEditView: View {

    let group: ExpenseGroup
    var onDelete: () -> Void = {}

    @State private var name: String
    @State private var colorName: String?
    @State private var iconName: String?
    @State private var showingDeleteConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    @Query private var budgets: [Budget]

    init(group: ExpenseGroup, onDelete: @escaping () -> Void = {}) {
        self.group = group
        self.onDelete = onDelete
        _name = State(initialValue: group.name)
        _colorName = State(initialValue: group.displayColorName)
        _iconName = State(initialValue: group.iconName)
    }

    var body: some View {
        NavigationStack {
            Form {
                GroupStylePreview(name: name, colorName: colorName, iconName: iconName)

                TextField("Name", text: $name)
                    .focused($isInputFocused)

                GroupStyleSections(name: name, colorName: $colorName, iconName: $iconName)

                Section {
                    Button("Delete Group", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete \(group.name)?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete",
                successMessage: "\(group.name) deleted",
                onConfirm: {
                    delete()
                },
                onDismiss: {
                    dismiss()
                    onDelete()
                }
            )
            .navigationTitle(Text("Edit Group"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty)
                    .tint(.blue)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
        }
    }

    private func save() {
        group.name = name
        group.colorName = colorName
        group.iconName = iconName
        DataStore.commit(modelContext)
        dismiss()
    }

    private func delete() {
        // Budget.group nullifies on delete, which would turn this group's budgets into overall ones.
        for budget in budgets where budget.group?.persistentModelID == group.persistentModelID {
            DataStore.delete(budget, from: modelContext)
        }
        DataStore.delete(group, from: modelContext)
    }
}


#Preview {
    GroupEditView(group: ExpenseGroup(name: "Food"))
}
