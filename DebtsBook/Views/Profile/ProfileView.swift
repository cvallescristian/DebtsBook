import SwiftUI
import SwiftData
import Auth
import UniformTypeIdentifiers

struct ProfileView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteExpensesConfirmation = false
    @State private var showingResetAppConfirmation = false
    @State private var authService = AuthService.shared
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var importResultMessage: String?
    @State private var showingImportResult = false
    @State private var showingSignIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let email = authService.session?.user.email {
                        Text(email)
                            .foregroundStyle(.secondary)
                        Button("Sign Out", role: .destructive) {
                            Task { await authService.signOut() }
                        }
                    } else {
                        Button("Sign In") {
                            showingSignIn = true
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if authService.session == nil {
                        Text("Sign in to connect and share expenses with friends who also use DebtsBook.")
                    }
                }
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
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Preparing export…", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export saves a JSON file with all your friends, expenses, groups, budgets, and activity. Import adds records from a previously exported file.")
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
                    Text("Deleting all expenses also deletes their activity. Resetting the app permanently deletes all friends, groups, budgets, expenses, and activity.")
                }
            }
            .confirmationModal(
                isPresented: $showingDeleteExpensesConfirmation,
                title: "Delete all expenses?",
                message: "This also deletes all activity. This action cannot be undone.",
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
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        try BackupService.importData(from: url, into: modelContext)
                        importResultMessage = "Import complete."
                    } catch {
                        importResultMessage = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    importResultMessage = "Import failed: \(error.localizedDescription)"
                }
                showingImportResult = true
            }
            .alert("Import Data", isPresented: $showingImportResult) {
                Button("OK") {}
            } message: {
                Text(importResultMessage ?? "")
            }
            .task {
                exportURL = try? BackupService.exportData(context: modelContext)
            }
            .sheet(isPresented: $showingSignIn) {
                SignInRequiredView()
            }
            .navigationTitle("Profile")
        }
    }

    private func deleteAllExpenses() {
        deleteAll(Expense.self)
        deleteAll(Activity.self)
    }

    private func resetApp() {
        deleteAll(Expense.self)
        deleteAll(Activity.self)
        deleteAll(Friend.self)
        deleteAll(ExpenseGroup.self)
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
