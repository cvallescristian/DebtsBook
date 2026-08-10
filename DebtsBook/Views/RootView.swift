import SwiftUI
import SwiftData

struct RootView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @State private var isUnlocked = false
    @State private var authService = AuthService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if !authService.isSignedIn {
                AuthView()
            } else if requireFaceID && !isUnlocked {
                LockScreenView(onUnlock: { isUnlocked = true })
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                isUnlocked = false
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await FriendSyncService.shared.pullFriends(into: modelContext) }
            }
        }
    }
}


#Preview {
    RootView()
        .modelContainer(PreviewSampleData.container)
}
