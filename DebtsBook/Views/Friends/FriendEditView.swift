import SwiftUI
import SwiftData

struct FriendEditView: View {
    
    let friend: Friend
    var onDelete: () -> Void = {}

    @State private var name: String
    @State private var showingDeleteConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    init(friend: Friend, onDelete: @escaping () -> Void = {}) {
        self.friend = friend
        self.onDelete = onDelete
        _name = State(initialValue: friend.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .focused($isInputFocused)

                Section {
                    Button("Delete Friend", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete \(friend.name)?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete",
                successMessage: "\(friend.name) deleted",
                onConfirm: {
                    delete()
                },
                onDismiss: {
                    dismiss()
                    onDelete()
                }
            )
            .navigationTitle(Text("Edit Friend"))
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
        friend.name = name
        dismiss()
    }

    private func delete() {
        modelContext.delete(friend)
    }
}


#Preview {
    FriendEditView(friend: Friend(name: "Test Name"))
}
