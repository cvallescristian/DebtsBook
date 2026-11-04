import Testing
import Foundation
import SwiftData
@testable import DebtsBook

@MainActor
struct AccountOwnershipTests {

    @Test func firstSignInAdoptsTheDevice() {
        #expect(AccountOwnership.decide(owner: nil, signedIn: "a", hasLocalData: true) == .adopt)
    }

    @Test func sameAccountProceeds() {
        #expect(AccountOwnership.decide(owner: "a", signedIn: "a", hasLocalData: true) == .proceed)
    }

    @Test func differentAccountWithDataAsks() {
        #expect(AccountOwnership.decide(owner: "a", signedIn: "b", hasLocalData: true) == .askToSwitch)
    }

    @Test func differentAccountOnEmptyDeviceAdopts() {
        #expect(AccountOwnership.decide(owner: "a", signedIn: "b", hasLocalData: false) == .adopt)
    }

    @Test func eraseLeavesNoLocalData() {
        let context = TestModelContainer.shared.mainContext
        context.insert(Friend(name: "Sam"))
        context.insert(PendingExpense(merchant: "Countdown", amount: 10, cardName: nil))
        #expect(AccountOwnership.hasLocalData(in: context))

        AccountOwnership.eraseLocalData(in: context)

        #expect(!AccountOwnership.hasLocalData(in: context))
    }
}
