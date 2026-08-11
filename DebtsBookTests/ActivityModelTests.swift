import Testing
import Foundation
@testable import DebtsBook

/// Covers the actor-vs-debt-direction bug: `performedByMe` (who did the action) and
/// `paidByMe` (which way the debt goes) are independent, and title wording must flip on
/// `performedByMe` alone — mixing them up previously made every synced entry read as if the
/// other person had done the action whenever `paidByMe` happened to be false.
struct ActivityModelTests {

    @Test func createdByMeReadsAsYou() {
        let activity = Activity(type: .created, expenseTitle: "Groceries", friendName: "Ana", amount: 20, paidByMe: true, performedByMe: true)
        #expect(activity.title == "You added \u{201C}Groceries\u{201D} with Ana.")
    }

    @Test func createdByFriendReadsAsFriend() {
        let activity = Activity(type: .created, expenseTitle: "Groceries", friendName: "Ana", amount: 20, paidByMe: false, performedByMe: false)
        #expect(activity.title == "Ana added \u{201C}Groceries\u{201D} with you.")
    }

    @Test func friendCanPerformAnActionWhileYouStillPaid() {
        // Ana added the expense, but marked that you were the one who paid — performedByMe
        // and paidByMe disagree, and the title must follow performedByMe, not paidByMe.
        let activity = Activity(type: .created, expenseTitle: "Taxi", friendName: "Ana", amount: 10, paidByMe: true, performedByMe: false)
        #expect(activity.title == "Ana added \u{201C}Taxi\u{201D} with you.")
        #expect(activity.resultText == "You get back \(Decimal(10).formatted(.currency(code: "NZD"))).")
    }

    @Test func updatedAndDeletedFollowPerformedByMe() {
        let updated = Activity(type: .updated, expenseTitle: "Rent", friendName: "Ana", amount: 5, paidByMe: true, performedByMe: false)
        #expect(updated.title == "Ana updated \u{201C}Rent\u{201D} with you.")

        let deleted = Activity(type: .deleted, expenseTitle: "Rent", friendName: "Ana", amount: 5, paidByMe: true, performedByMe: false)
        #expect(deleted.title == "Ana deleted \u{201C}Rent\u{201D} with you.")
        #expect(deleted.resultText == nil)
    }

    @Test func settledUpFollowsPerformedByMe() {
        let byMe = Activity(type: .settledUp, expenseTitle: "", friendName: "Ana", amount: 15, paidByMe: true, performedByMe: true)
        #expect(byMe.title == "You settled up with Ana.")

        let byFriend = Activity(type: .settledUp, expenseTitle: "", friendName: "Ana", amount: 15, paidByMe: true, performedByMe: false)
        #expect(byFriend.title == "Ana settled up with you.")
    }

    @Test func paidWordingFollowsDebtDirectionRegardlessOfActor() {
        // .paid describes which way the settlement money moved, which is symmetric across
        // viewers already — it should NOT depend on performedByMe.
        let friendPaysYouBack = Activity(type: .paid, expenseTitle: "Movie", friendName: "Ana", amount: 9, paidByMe: true, performedByMe: false)
        #expect(friendPaysYouBack.title == "Ana paid you.")

        let youPayFriendBack = Activity(type: .paid, expenseTitle: "Movie", friendName: "Ana", amount: 9, paidByMe: false, performedByMe: false)
        #expect(youPayFriendBack.title == "You paid Ana.")
    }

    @Test func personalActivityHasNoFriendWording() {
        let activity = Activity(type: .created, expenseTitle: "Coffee", amount: 5, paidByMe: true)
        #expect(activity.title == "You added \u{201C}Coffee\u{201D}.")
        #expect(activity.resultText == "You spent \(Decimal(5).formatted(.currency(code: "NZD"))).")
    }

    @Test func defaultPerformedByMeIsTrue() {
        // Every activity created locally (the overwhelming majority of call sites) never
        // passes performedByMe explicitly — the default must be true, or every local action
        // would misread as performed by the friend.
        let activity = Activity(type: .created, expenseTitle: "Coffee", amount: 5, paidByMe: true)
        #expect(activity.performedByMe == true)
    }
}
