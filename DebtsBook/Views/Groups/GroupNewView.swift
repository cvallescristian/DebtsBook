import SwiftUI
import SwiftData

struct GroupNewView: View {

    @State private var name: String = ""
    @State private var colorName: String?
    @State private var iconName: String? = GroupStyle.fallbackIconName
    /// Once the user picks an icon themselves, stop replacing it as they type the name.
    @State private var iconChosenManually = false
    @Query private var groups: [ExpenseGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                GroupStylePreview(name: name, colorName: colorName, iconName: iconName)

                TextField("Name", text: $name)
                    .focused($isInputFocused)

                GroupStyleSections(name: name, colorName: $colorName, iconName: iconBinding)
            }
            .onAppear {
                if colorName == nil {
                    colorName = GroupStyle.nextColorName(existing: groups)
                }
            }
            .onChange(of: name) {
                if !iconChosenManually {
                    iconName = GroupStyle.defaultIconName(for: name)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("New Group"))
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

    private var iconBinding: Binding<String?> {
        Binding(
            get: { iconName },
            set: {
                iconName = $0
                iconChosenManually = true
            }
        )
    }

    private func save() {
        let group = ExpenseGroup(name: name)
        group.colorName = colorName
        group.iconName = iconName
        DataStore.insert(group, into: modelContext)
        dismiss()
    }
}


#Preview {
    GroupNewView()
}
