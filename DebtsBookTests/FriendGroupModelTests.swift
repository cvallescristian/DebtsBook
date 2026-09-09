import Testing
import Foundation
@testable import DebtsBook

struct FriendGroupModelTests {

    @Test func friendInitializesWithNameAndNoSyncState() {
        let friend = Friend(name: "Ana")
        #expect(friend.name == "Ana")
        #expect(friend.remoteID == nil)
        #expect(friend.linkedUserID == nil)
        #expect(friend.connectionID == nil)
        #expect(friend.photoData == nil)
        #expect(friend.iconName == nil)
        #expect(friend.lastSyncedAt == nil)
    }

    @Test func groupInitializesWithName() {
        let group = ExpenseGroup(name: "Food")
        #expect(group.name == "Food")
    }
}
