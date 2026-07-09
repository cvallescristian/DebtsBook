import SwiftUI
import SwiftData

struct RootView: View {

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("requireFaceID") private var requireFaceID: Bool = false
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if requireFaceID && !isUnlocked {
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
    }
}


#Preview {
    RootView()
        .modelContainer(PreviewSampleData.container)
}
