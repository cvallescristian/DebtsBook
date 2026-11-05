import SwiftUI
import SwiftData
import Auth

struct RootView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @State private var isUnlocked = false
    @State private var showingAccountSwitch = false
    @State private var hasBeenInBackground = false
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
                hasBeenInBackground = true
                SyncCoordinator.scheduleBackgroundRefresh()
            } else if newPhase == .active {
                Task { await SyncCoordinator.syncAll(into: modelContext) }
                // UI tests open the sheet by backgrounding and reopening the app, so the test
                // decides when it appears instead of a timer racing a slow simulator.
                if hasBeenInBackground && TestModelContainer.isUITesting && ProcessInfo.processInfo.arguments.contains("-accountSwitch") {
                    showingAccountSwitch = true
                }
            }
        }
        .onAppear {
            SyncStatus.shared.startMonitoring {
                Task { await SyncCoordinator.syncAll(into: modelContext) }
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                checkAccountOwnership()
            }
        }
        .sheet(isPresented: $showingAccountSwitch) {
            AccountSwitchView {
                showingAccountSwitch = false
                confirmOwnership()
            }
                .interactiveDismissDisabled()
        }
    }

    private func checkAccountOwnership() {
        guard let userID = authService.session?.user.id else { return }
        let decision = AccountOwnership.decide(
            owner: AccountOwnership.owner,
            signedIn: userID.uuidString,
            hasLocalData: AccountOwnership.hasLocalData(in: modelContext)
        )
        switch decision {
        case .adopt, .proceed:
            confirmOwnership()
        case .askToSwitch:
            showingAccountSwitch = true
        }
    }

    private func confirmOwnership() {
        guard let userID = authService.session?.user.id else { return }
        AccountOwnership.owner = userID.uuidString
        authService.confirmedOwnerID = userID
        NotificationService.shared.registerIfEnabled()
        Task { await SyncCoordinator.syncAll(into: modelContext) }
    }
}


#Preview {
    RootView()
        .modelContainer(PreviewSampleData.container)
}
