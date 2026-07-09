import SwiftUI
import SwiftData

struct FriendEditView: View {
    
    let friend: Friend
    var onDelete: () -> Void = {}

    @State private var name: String
    @State private var showingDeleteConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(friend: Friend, onDelete: @escaping () -> Void = {}) {
        self.friend = friend
        self.onDelete = onDelete
        _name = State(initialValue: friend.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                Section {
                    Button("Delete Friend", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .confirmationModal(
                isPresented: $showingDeleteConfirmation,
                title: "Delete \(friend.name)?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete"
            ) {
                delete()
            }
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
            }
        }
    }

    private func save() {
        friend.name = name
        dismiss()
    }

    private func delete() {
        modelContext.delete(friend)
        dismiss()
        onDelete()
    }
}


#Preview {
    FriendEditView(friend: Friend(name: "Test Name"))
}
