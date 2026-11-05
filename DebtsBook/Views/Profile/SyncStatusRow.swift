import SwiftUI
import SwiftData

/// Where the user's data lives right now, styled like a friend's "Connected" label.
/// Signed in, tapping it syncs now.
struct SyncStatusRow: View {
    let isSignedIn: Bool
    @Environment(\.modelContext) private var modelContext
    private var status = SyncStatus.shared

    init(isSignedIn: Bool) {
        self.isSignedIn = isSignedIn
    }

    var body: some View {
        // Re-evaluates every minute so "Synced 2 min ago" stays current.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = SyncStatus.summary(
                isSignedIn: isSignedIn,
                state: status.state,
                isOnline: status.isOnline,
                pendingChanges: status.pendingChanges,
                lastSyncedAt: status.lastSyncedAt,
                now: context.date
            )
            if isSignedIn {
                Button {
                    Task { await SyncCoordinator.syncAll(into: modelContext) }
                } label: {
                    HStack {
                        label(for: summary)
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(status.state == .syncing)
                .accessibilityHint("Syncs now")
            } else {
                label(for: summary)
            }
        }
    }

    private func label(for summary: SyncStatus.Summary) -> some View {
        Label(summary.text, systemImage: summary.systemImage)
            .foregroundStyle(color(for: summary))
            .accessibilityIdentifier("syncStatus")
    }

    private func color(for summary: SyncStatus.Summary) -> Color {
        if summary.isWarning {
            return .orange
        }
        if isSignedIn {
            return .blue
        }
        return .secondary
    }
}
