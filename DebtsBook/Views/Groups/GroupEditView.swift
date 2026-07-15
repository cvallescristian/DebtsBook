import SwiftUI
import SwiftData

struct GroupEditView: View {

    let group: ExpenseGroup
    var onDelete: () -> Void = {}

    @State private var name: String
    @State private var showingDeleteConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    init(group: ExpenseGroup, onDelete: @escaping () -> Void = {}) {
        self.group = group
        self.onDelete = onDelete
        _name = State(initialValue: group.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .focused($isInputFocused)

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
        dismiss()
    }

    private func delete() {
        modelContext.delete(group)
    }
}


#Preview {
    GroupEditView(group: ExpenseGroup(name: "Food"))
}
