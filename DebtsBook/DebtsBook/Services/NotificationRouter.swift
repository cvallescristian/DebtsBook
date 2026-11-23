import Foundation
import Observation

/// Where tapping a push notification takes you, built from the keys notify-activity adds to the payload.
nonisolated enum NotificationRoute: Equatable {
    case expense(remoteID: UUID)
    case friends
    case activity

    init(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String
        let expenseID = (userInfo["expense_id"] as? String).flatMap(UUID.init(uuidString:))
        switch type {
        case "created", "updated", "paid":
            if let expenseID {
                self = .expense(remoteID: expenseID)
            } else {
                self = .activity
            }
        case "settledUp":
            self = .friends
        default:
            // "deleted" has no expense left to open; unknown types fall back to the log too.
            self = .activity
        }
    }
}

@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// Set when a notification is tapped, cleared by MainTabView once it has navigated.
    var pendingRoute: NotificationRoute?

    private init() {}
}
