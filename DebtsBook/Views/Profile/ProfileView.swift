import SwiftUI
import SwiftData

struct ProfileView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteExpensesConfirmation = false
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
                    Button("Delete All Expenses", role: .destructive) {
                        showingDeleteExpensesConfirmation = true
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
                isPresented: $showingDeleteExpensesConfirmation,
                title: "Delete all expenses?",
                message: "This action cannot be undone.",
                confirmLabel: "Delete All Expenses",
                successMessage: "All expenses deleted"
            ) {
                deleteAllExpenses()
            }
            .confirmationModal(
                isPresented: $showingResetAppConfirmation,
                title: "Reset the app?",
                message: "This permanently deletes all friends, expenses, and activity. This action cannot be undone.",
                confirmLabel: "Reset App",
                successMessage: "App reset"
            ) {
                resetApp()
            }
            .navigationTitle("Profile")
        }
    }

    private func deleteAllExpenses() {
        deleteAll(Expense.self)
    }

    private func resetApp() {
        deleteAll(Expense.self)
        deleteAll(Activity.self)
        deleteAll(Friend.self)
        deleteAll(Budget.self)
    }

    /// Fetches and deletes every instance individually instead of using the batch `delete(model:)`
    /// API, which can silently skip rows with nil optional relationships (e.g. personal expenses'
    /// activities, which have no friend).
    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let objects = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
        for object in objects {
            modelContext.delete(object)
        }
    }
}


#Preview {
    ProfileView()
        .modelContainer(PreviewSampleData.container)
}
