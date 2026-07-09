import SwiftUI
import SwiftData

struct ProfileView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteActivityConfirmation = false
    @State private var showingResetAppConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("Security") {
                    Toggle("Require Face ID", isOn: $requireFaceID)
                }
                Section {
                    Button("Delete All Activity", role: .destructive) {
                        showingDeleteActivityConfirmation = true
                    }
                    Button("Reset App", role: .destructive) {
                        showingResetAppConfirmation = true
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Resetting the app permanently deletes all friends, expenses, and activity.")
                }
            }
            .confirmationModal(
                isPresented: $showingDeleteActivityConfirmation,
                title: "Delete all activity?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete All Activity"
            ) {
                deleteAllActivity()
            }
            .confirmationModal(
                isPresented: $showingResetAppConfirmation,
                title: "Reset the app?",
                message: "This permanently deletes all friends, expenses, and activity. This action cannot be undone.",
                confirmLabel: "Reset App"
            ) {
                resetApp()
            }
            .navigationTitle("Profile")
        }
    }

    private func deleteAllActivity() {
        try? modelContext.delete(model: Activity.self)
    }

    private func resetApp() {
        try? modelContext.delete(model: Expense.self)
        try? modelContext.delete(model: Activity.self)
        try? modelContext.delete(model: Friend.self)
    }
}


#Preview {
    ProfileView()
        .modelContainer(PreviewSampleData.container)
}
