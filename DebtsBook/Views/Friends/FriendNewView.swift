import SwiftUI
import SwiftData

struct FriendNewView: View {
    
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .focused($isInputFocused)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
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
        modelContext.insert(friend)
        dismiss()
    }
}


#Preview {
    FriendNewView()
}
