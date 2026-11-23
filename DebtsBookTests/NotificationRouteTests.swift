import Testing
import Foundation
@testable import DebtsBook

struct NotificationRouteTests {

    private let expenseID = UUID()

    @Test(arguments: ["created", "updated", "paid"])
    func expenseActivityOpensTheExpense(type: String) {
        let route = NotificationRoute(userInfo: ["type": type, "expense_id": expenseID.uuidString])
        #expect(route == .expense(remoteID: expenseID))
    }

    @Test func expenseActivityWithoutIDFallsBackToActivity() {
        #expect(NotificationRoute(userInfo: ["type": "created"]) == .activity)
        #expect(NotificationRoute(userInfo: ["type": "paid", "expense_id": "not-a-uuid"]) == .activity)
    }

    @Test func deletedOpensActivity() {
        let route = NotificationRoute(userInfo: ["type": "deleted", "expense_id": expenseID.uuidString])
        #expect(route == .activity)
    }

    @Test func settledUpOpensFriends() {
        #expect(NotificationRoute(userInfo: ["type": "settledUp"]) == .friends)
    }

    @Test func unknownOrMissingTypeOpensActivity() {
        #expect(NotificationRoute(userInfo: ["type": "somethingNew"]) == .activity)
        #expect(NotificationRoute(userInfo: [:]) == .activity)
    }
}
