import SwiftUI
import SwiftData

struct FriendEditView: View {
    
    let friend: Friend
    var onDelete: () -> Void = {}

    @State private var name: String
    @State private var photoData: Data?
    @State private var iconName: String?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var showingDeleteError: Bool = false
    @State private var deleteAttempted: Bool = false
    @State private var deleteSucceeded: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    init(friend: Friend, onDelete: @escaping () -> Void = {}) {
        self.friend = friend
        self.onDelete = onDelete
        _name = State(initialValue: friend.name)
        _photoData = State(initialValue: friend.photoData)
        _iconName = State(initialValue: friend.iconName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarPhotoPicker(name: name, photoData: $photoData, iconName: $iconName)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

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
                    await delete()
                },
                onDismiss: {
                    guard deleteAttempted else { return }
                    if deleteSucceeded {
                        dismiss()
                        onDelete()
                    } else {
                        showingDeleteError = true
                    }
                }
            )
            .alert("Couldn't Delete Friend", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(ConnectService.shared.lastError ?? FriendSyncService.shared.lastError ?? "Please check your connection and try again.")
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
        friend.photoData = photoData
        friend.iconName = iconName
        Task { await FriendSyncService.shared.push(friend: friend) }
        dismiss()
    }

    private func delete() async -> Bool {
        deleteAttempted = true
        if friend.connectionID != nil {
            guard await ConnectService.shared.disconnect(friend: friend, context: modelContext) else {
                return false
            }
        }
        guard await FriendSyncService.shared.delete(friend: friend) else {
            return false
        }
        modelContext.delete(friend)
        deleteSucceeded = true
        return true
    }
}


#Preview {
    FriendEditView(friend: Friend(name: "Test Name"))
}
