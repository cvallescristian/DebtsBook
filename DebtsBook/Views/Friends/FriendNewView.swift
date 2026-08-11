import SwiftUI
import SwiftData

struct FriendNewView: View {
    
    @State private var name: String = ""
    @State private var photoData: Data?
    @State private var iconName: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

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
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("New Friend"))
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
        let friend = Friend(name: name)
        friend.photoData = photoData
        friend.iconName = iconName
        modelContext.insert(friend)
        Task { await FriendSyncService.shared.push(friend: friend) }
        dismiss()
    }
}


#Preview {
    FriendNewView()
}
