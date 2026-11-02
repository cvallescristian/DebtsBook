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
            if authService.isRestoringSession {
                LaunchLoadingView()
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
                SyncCoordinator.scheduleBackgroundRefresh()
            } else if newPhase == .active {
                Task { await SyncCoordinator.syncAll(into: modelContext) }
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                NotificationService.shared.registerIfEnabled()
                Task { await SyncCoordinator.syncAll(into: modelContext) }
            }
        }
    }
}


#Preview {
    RootView()
        .modelContainer(PreviewSampleData.container)
}
