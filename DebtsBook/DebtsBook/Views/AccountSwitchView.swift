import SwiftUI
import SwiftData

/// Shown when someone signs in with a different account than the one this device's data
/// belongs to. Nothing syncs until they choose.
struct AccountSwitchView: View {

    let onSwitch: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var showingEraseConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("This iPhone Has Data From Another Account")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("To use this account, the friends, expenses, groups and budgets on this iPhone will be erased. Your other account's shared data stays safe online.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button(role: .destructive) {
                    showingEraseConfirmation = true
                } label: {
                    Text("Erase and Switch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)

                Button("Cancel and Sign Out") {
                    Task {
                        await AuthService.shared.signOut()
                        dismiss()
                    }
                }
                .controlSize(.large)
            }
            .padding()
            .confirmationDialog("Erase all data on this iPhone?", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
                Button("Erase All Data", role: .destructive) {
                    AccountOwnership.eraseLocalData(in: modelContext)
                    onSwitch()
                }
            } message: {
                Text("This can't be undone. Export a backup first if you want to keep a copy.")
            }
        }
        .onAppear {
            exportURL = try? BackupService.exportData(context: modelContext)
        }
        .onDisappear {
            if let exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
        }
    }
}

#Preview {
    AccountSwitchView(onSwitch: {})
        .modelContainer(PreviewSampleData.container)
}
