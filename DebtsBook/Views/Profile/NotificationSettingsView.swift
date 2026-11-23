import SwiftUI

struct NotificationSettingsView: View {

    @AppStorage(NotificationService.enabledKey) private var isEnabled: Bool = false
    @AppStorage(NotificationService.expenseChangesKey) private var notifyExpenseChanges: Bool = true
    @AppStorage(NotificationService.paidKey) private var notifyPaid: Bool = true
    @AppStorage(NotificationService.settledUpKey) private var notifySettledUp: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Allow Notifications", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, isOn in
                        guard isOn else {
                            Task { await NotificationService.shared.disable() }
                            return
                        }
                        Task {
                            if await !NotificationService.shared.enable() {
                                isEnabled = false
                            }
                        }
                    }
            } footer: {
                Text("Get notified when a connected friend changes a shared expense.")
            }
            Section("Notify Me When a Friend") {
                Toggle("Adds, Edits, or Deletes an Expense", isOn: shown($notifyExpenseChanges))
                Toggle("Marks an Expense as Paid", isOn: shown($notifyPaid))
                Toggle("Settles Up With Me", isOn: shown($notifySettledUp))
            }
            .disabled(!isEnabled)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notifyExpenseChanges) { updatePreferences() }
        .onChange(of: notifyPaid) { updatePreferences() }
        .onChange(of: notifySettledUp) { updatePreferences() }
    }

    /// Reads as off while notifications are off, but keeps the saved choice for when they're turned back on.
    private func shown(_ preference: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { isEnabled && preference.wrappedValue },
            set: { preference.wrappedValue = $0 }
        )
    }

    private func updatePreferences() {
        Task { await NotificationService.shared.updatePreferences() }
    }
}


#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
