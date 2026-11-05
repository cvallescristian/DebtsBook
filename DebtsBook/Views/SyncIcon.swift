import SwiftUI

/// Small cloud next to any synced item: blue check once it's on the server, grey arrow while
/// waiting to upload. Hidden when signed out, since nothing syncs then.
struct SyncIcon<Item: SyncedModel>: View {
    let item: Item

    var body: some View {
        if AuthService.shared.isSignedIn {
            if item.isSynced {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Synced")
            } else {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Waiting to sync")
            }
        }
    }
}
