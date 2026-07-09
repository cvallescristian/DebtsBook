import SwiftUI
import SwiftData

@main
struct DebtsBookApp: App {
    var body: some Scene {
        WindowGroup {
            FriendView()
        }
        .modelContainer(for: Friend.self)
    }
}
