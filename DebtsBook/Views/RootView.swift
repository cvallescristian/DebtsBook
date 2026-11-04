import SwiftUI
import SwiftData
import Auth

struct RootView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @State private var isUnlocked = false
    @State private var showingAccountSwitch = false
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
                checkAccountOwnership()
            }
        }
        .task {
            // Delayed so the test can open a tab with rows first, like a real sign-in from Profile.
            if TestModelContainer.isUITesting && ProcessInfo.processInfo.arguments.contains("-accountSwitch") {
                try? await Task.sleep(for: .seconds(3))
                showingAccountSwitch = true
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
