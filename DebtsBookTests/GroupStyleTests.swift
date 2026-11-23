import Testing
import Foundation
@testable import DebtsBook

struct GroupStyleTests {

    @Test func defaultIconMatchesNameKeywords() {
        #expect(GroupStyle.defaultIconName(for: "Food") == "fork.knife")
        #expect(GroupStyle.defaultIconName(for: "Weekly Groceries") == "cart.fill")
        #expect(GroupStyle.defaultIconName(for: "Transport") == "car.fill")
        #expect(GroupStyle.defaultIconName(for: "Credit card") == "creditcard.fill")
    }

    @Test func defaultIconMatchesWordStartsOnly() {
        #expect(GroupStyle.defaultIconName(for: "Education") == "graduationcap.fill")
        #expect(GroupStyle.defaultIconName(for: "Misc") == GroupStyle.fallbackIconName)
    }

    @Test func nextColorSkipsColorsAlreadyUsed() {
        let food = ExpenseGroup(name: "Food")
        food.colorName = "blue"
        let fun = ExpenseGroup(name: "Fun")
        fun.colorName = "orange"
        #expect(GroupStyle.nextColorName(existing: [food, fun]) == "green")
    }

    @Test func groupWithoutColorGetsAStableDisplayColor() {
        let group = ExpenseGroup(name: "Food")
        #expect(GroupStyle.colorNames.contains(group.displayColorName))
        #expect(group.displayColorName == ExpenseGroup(name: "Food").displayColorName)
    }
}
