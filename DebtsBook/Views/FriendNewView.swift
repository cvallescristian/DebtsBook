import SwiftUI
import SwiftData

struct FriendNewView: View {
    
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
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
